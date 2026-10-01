'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const test = require('node:test');

const pluginRoot = path.resolve(__dirname, '..');
const manifestPath = path.join(pluginRoot, 'kimi.plugin.json');
const permissionRequestHook = path.join(pluginRoot, 'hooks', 'permission-request.sh');
const fixtureRoot = path.join(__dirname, 'fixtures', 'hook-events');
const contract = JSON.parse(fs.readFileSync(path.join(pluginRoot, 'contracts', 'kimi-hook-consumers.v1.json'), 'utf8'));
const temporaryProjects = [];

// Kimi's exactly-sixteen hook events, declared inline in kimi.plugin.json and
// mapped one-to-one onto contracts/kimi-hook-consumers.v1.json consumers.
// Ported from lazyzcode v1.3.4 tests/hook-lifecycle-pipeline.test.js, which
// exercises ZCode's seven-event hooks.json surface.

test.after(() => {
  for (const projectDir of temporaryProjects) fs.rmSync(projectDir, { recursive: true, force: true });
});

function readDeclaration() {
  return JSON.parse(fs.readFileSync(manifestPath, 'utf8')).hooks;
}

function fixture(name, projectDir) {
  return JSON.parse(fs.readFileSync(path.join(fixtureRoot, `${name}.json`), 'utf8').replaceAll('${PROJECT_DIR}', projectDir));
}

function setupProject(status = 'executing') {
  const projectDir = fs.mkdtempSync(path.join(os.tmpdir(), 'lazykimi-hook-event-'));
  temporaryProjects.push(projectDir);
  const runDir = path.join(projectDir, '.lazykimi', 'runs', 'run-001');
  fs.mkdirSync(runDir, { recursive: true });
  fs.writeFileSync(path.join(runDir, 'state.json'), `${JSON.stringify({ status, progress: { completed_count: 2 } }, null, 2)}\n`);
  return { projectDir, runDir };
}

function dispatch(payload, projectDir) {
  return spawnSync('bash', [permissionRequestHook], {
    cwd: projectDir,
    env: { ...process.env, CWD: projectDir, LAZYKIMI_PLUGIN_ROOT: pluginRoot },
    input: `${JSON.stringify(payload)}\n`,
    encoding: 'utf8',
    maxBuffer: 4 * 1024 * 1024,
    timeout: 5_000,
  });
}

function recordedEvents(projectDir) {
  const root = path.join(projectDir, '.lazykimi', 'hook-events');
  if (!fs.existsSync(root)) return [];
  return fs.readdirSync(root, { recursive: true })
    .map(name => path.join(root, name.toString()))
    .filter(file => file.endsWith('.json'));
}

test('declares exactly the sixteen Kimi hook events with one consumer each', () => {
  // Given: the inline Kimi hook declaration and the Kimi hook-consumer contract.
  const declaration = readDeclaration();
  const byEvent = new Map(declaration.map((entry) => [entry.event, entry]));

  // Then: the event set matches Kimi's sixteen-event surface and the contract.
  assert.equal(declaration.length, 16);
  assert.deepEqual(new Set(byEvent.keys()), new Set(Object.keys(contract.events)));
  for (const [event, consumer] of Object.entries(contract.events)) {
    const entry = byEvent.get(event);
    assert.ok(entry, `${event} missing from kimi.plugin.json`);
    assert.equal(entry.command, `bash ./${consumer.consumer}`, `${event} handler drifted`);
  }
  assert.equal(byEvent.get('PreToolUse').matcher, 'Write|Edit|Bash');
  assert.equal(byEvent.get('SessionStart').timeout, 10);
  // The critical-8 registration split (install-hooks.sh TOML route) matches the
  // contract's critical flags exactly.
  assert.deepEqual(
    declaration.filter((entry) => contract.events[entry.event].critical).map((entry) => entry.event).sort(),
    ['PermissionRequest', 'PermissionResult', 'PostToolUse', 'PostToolUseFailure', 'PreToolUse', 'SessionStart', 'Stop', 'UserPromptSubmit'],
  );
});

test('hook timeouts and payload boundary match the shared Kimi contract', () => {
  const declaration = readDeclaration();
  const timeoutFor = (event) => declaration.find((entry) => entry.event === event).timeout;
  assert.equal(timeoutFor('SessionStart'), 10);
  assert.equal(timeoutFor('Stop'), 10);
  assert.equal(timeoutFor('PreToolUse'), contract.boundary.timeout_seconds);
  assert.equal(timeoutFor('PermissionRequest'), contract.boundary.timeout_seconds);
  assert.equal(timeoutFor('PostToolUse'), contract.boundary.timeout_seconds);
  assert.equal(contract.boundary.max_payload_bytes, 1_048_576);
  assert.deepEqual(contract.boundary.exit_codes, { accepted: 0, rejected: 2, internal_error: 70 });
  assert.deepEqual(contract.boundary.required_common_fields, ['cwd', 'hook_event_name']);
  assert.deepEqual(contract.boundary.omitted_common_fields, ['transcript_path']);
  assert.ok(contract.boundary.dual_key_parsing.includes('tool_name|toolName'));
});

test('records an advisory normalized permission request without stdout output', () => {
  // Given: an active run and the documented PermissionRequest fixture.
  const { projectDir } = setupProject();
  const payload = fixture('PermissionRequest', projectDir);

  // When: the event crosses the real hook boundary.
  const result = dispatch(payload, projectDir);

  // Then: the hook prints nothing, exits 0, and persists one advisory record.
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, '');
  const records = recordedEvents(projectDir);
  assert.equal(records.length, 1);
  const record = JSON.parse(fs.readFileSync(records[0], 'utf8'));
  assert.equal(record.raw_event, 'PermissionRequest');
  assert.equal(record.canonical_event, 'permission-request');
  assert.equal(record.consumer.name, 'permission-audit');
  assert.equal(record.consumer.mode, 'advisory');
  assert.equal(record.consumer.completion_authority, false);
  assert.equal(record.payload.request_id, 'perm-001');
  assert.equal(record.payload.tool_name, 'Bash');
});

test('omits transcript paths and redacts secret-like fields from persisted records', () => {
  // Given: a permission request carrying a transcript path and secret-shaped key/value.
  const { projectDir } = setupProject('complete');
  const payload = fixture('PermissionRequest', projectDir);
  payload.transcript_path = '/private/tmp/session.jsonl';
  payload.api_key = 'sk-abcdefghijklmnopqrstuvwxyz123456';
  payload.reason = 'Run the suite. Bearer abcdefghijklmnopqrstuvwxyz';

  // When: the hook normalizes the payload.
  const result = dispatch(payload, projectDir);
  const records = recordedEvents(projectDir);
  const record = JSON.parse(fs.readFileSync(records[0], 'utf8'));
  const serialized = JSON.stringify(record);

  // Then: secrets and transcripts never reach the record and the hook still exits cleanly.
  assert.equal(result.status, 0);
  assert.equal(record.payload.transcript_path, undefined);
  assert.equal(record.payload.api_key, undefined);
  assert.equal(serialized.includes('sk-abcdefghijklmnopqrstuvwxyz'), false);
  assert.equal(serialized.includes('abcdefghijklmnopqrstuvwxyz'), false);
  assert.equal(serialized.includes('session.jsonl'), false);
});

test('repeated delivery is idempotent and permission events never complete work', () => {
  // Given: an active run whose progress is incomplete and one permission request delivery.
  const { projectDir, runDir } = setupProject();
  const payload = fixture('PermissionRequest', projectDir);

  // When: the identical event is delivered twice.
  const first = dispatch(payload, projectDir);
  const duplicate = dispatch(payload, projectDir);
  const state = JSON.parse(fs.readFileSync(path.join(runDir, 'state.json'), 'utf8'));

  // Then: only one record exists, the hook exits 0 both times, and completion-bearing state is untouched.
  assert.equal(first.status, 0);
  assert.equal(duplicate.status, 0);
  assert.equal(recordedEvents(projectDir).length, 1);
  assert.equal(state.status, 'executing');
  assert.deepEqual(state.progress, { completed_count: 2 });
  assert.equal(state.hook_lifecycle.last_permission.outcome, 'requested');
  assert.equal(state.hook_lifecycle.last_permission.completion_authority, false);
});

test('refuses malformed oversized incomplete and unsupported payloads with typed stderr and exit 0', () => {
  // Given: hostile inputs spanning the hook boundary.
  const { projectDir } = setupProject();
  const cases = [
    ['malformed_json', '{not-json'],
    ['payload_too_large', JSON.stringify({ ...fixture('PermissionRequest', projectDir), reason: 'x'.repeat(1_200 * 1024) })],
    ['missing_event_field', JSON.stringify({ ...fixture('PermissionRequest', projectDir), request_id: undefined, tool_name: undefined })],
    ['missing_common_field', JSON.stringify({ ...fixture('PermissionRequest', projectDir), session_id: undefined })],
    ['unsupported_event', JSON.stringify({ ...fixture('PermissionRequest', projectDir), hook_event_name: 'PostCompact' })],
  ];

  // When/Then: every hostile payload is refused with a typed reason, no stdout, exit 0.
  for (const [reason, input] of cases) {
    const result = spawnSync('bash', [permissionRequestHook], {
      cwd: projectDir,
      env: { ...process.env, CWD: projectDir, LAZYKIMI_PLUGIN_ROOT: pluginRoot },
      input,
      encoding: 'utf8',
      maxBuffer: 4 * 1024 * 1024,
      timeout: 5_000,
    });
    assert.equal(result.status, 0, `${reason} must stay advisory`);
    assert.equal(result.stdout, '', `${reason} must not print to stdout`);
    assert.equal(JSON.parse(result.stderr).reason, reason);
  }
});

test('stop-gate reads run state through argv and never executes a hostile project path', (t) => {
  // Given: a project whose directory name contains a Python quote-escape.
  // A stop-gate that interpolated the state path into a python -c string would
  // execute code on a name like this one; the ported gate passes paths as argv.
  const hostileName = "inj'+__import__('os').system('touch ./PWNED')+'";
  const projectRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'lk-hostile-'));
  const hostileRoot = path.join(projectRoot, hostileName);
  fs.mkdirSync(path.join(hostileRoot, '.lazykimi', 'runs', 'run-1'), { recursive: true });
  fs.writeFileSync(path.join(hostileRoot, '.lazykimi', 'runs', 'run-1', 'state.json'), '{"status":"active"}\n');
  t.after(() => fs.rmSync(projectRoot, { recursive: true, force: true }));

  // When: a Stop event fires in the hostile project.
  const payload = JSON.stringify({
    session_id: 'hostile-quote-check', cwd: hostileRoot,
    hook_event_name: 'Stop', stop_hook_active: false,
  });
  const result = spawnSync('bash', [path.join(pluginRoot, 'hooks', 'stop-gate.sh')], {
    input: payload, encoding: 'utf8',
    env: { ...process.env, LAZYKIMI_PLUGIN_ROOT: pluginRoot, CWD: hostileRoot },
  });

  // Then: the gate treats the run as active (exit 0, completion reminder)
  // and no interpolated payload ever executed.
  assert.equal(result.status, 0, result.stderr);
  assert.equal(fs.existsSync(path.join(projectRoot, 'PWNED')), false, 'arbitrary code executed');
});
