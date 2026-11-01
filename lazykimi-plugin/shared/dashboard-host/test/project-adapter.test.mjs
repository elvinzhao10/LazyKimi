import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { spawn } from 'node:child_process';
import { mkdtemp, mkdir, readFile, readdir, realpath, rm, stat, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { digest, host, plugin, processCall, testPython } from './fixture.mjs';
import { ACTIVITY_OBSERVER, producerAttemptObservations } from '../project.mjs';
import { capabilities } from '../capabilities.mjs';
import { RUNTIMES } from '../../project/contract.mjs';

const pythonDir = testPython.includes('/') ? dirname(testPython) : null;
const PATH_PREFIX = [pythonDir, dirname(process.execPath)].filter(Boolean).join(':');
const environment = PATH_PREFIX ? { PATH: `${PATH_PREFIX}:${process.env.PATH}` } : {};
const projectCLI = join(host, 'project.mjs');
const vendoredCLI = join(plugin, 'shared/project/cli.mjs');
const server = join(plugin, 'mcp/status-dashboard/server.sh');
const PROJECT_ID = 'project:kimi-platform';
const ACTOR = 'test:kimi-project';

async function tree(root, prefix = '') {
  const names = await readdir(join(root, prefix), { withFileTypes: true });
  const files = [];
  for (const entry of names.sort((left, right) => left.name.localeCompare(right.name))) {
    const relative = prefix ? `${prefix}/${entry.name}` : entry.name;
    if (entry.isDirectory()) files.push(...await tree(root, relative));
    else files.push(relative);
  }
  return files;
}

function command(operation, revision, payload, id = `${operation}:${revision}`) {
  return { schema_version: 1, command_id: id, project_id: PROJECT_ID, expected_revision: revision, operation, payload };
}

const PLAN_DOCUMENT = ['# Kimi execution plan',
  '',
  'Intro prose that no edit may touch.',
  '',
  '```bash',
  'echo fenced example stays byte-identical',
  '```',
  '',
  '## Tasks',
  '',
  '- [ ] [C1] Kimi criterion one',
  '- [ ] [C2] Kimi criterion two',
  '',
  'Closing prose.',
  ''].join('\n');

const WAITER = ['import { stat } from "node:fs/promises";',
  'const release = process.argv[2];',
  'const deadline = Date.now() + 12000;',
  'for (;;) {',
  '  try { await stat(release); process.stdout.write("{\\"released\\":true}\\n"); process.exit(0); }',
  '  catch { if (Date.now() > deadline) process.exit(8); }',
  '  await new Promise(resolve => setTimeout(resolve, 50));',
  '}',
  ''].join('\n');

async function projectFixture() {
  const root = await realpath(await mkdtemp(join(tmpdir(), 'lazykimi-project-')));
  const gitEnv = { GIT_CONFIG_NOSYSTEM: '1', HOME: root, ...environment };
  for (const args of [['init', '-q'], ['config', 'user.name', 'Kimi Project QA'], ['config', 'user.email', 'kimi@example.invalid']]) {
    const result = await processCall(['git', '-C', root, ...args], '', gitEnv);
    if (result.code) throw new Error(result.stderr);
  }
  await mkdir(join(root, 'docs'), { recursive: true });
  await writeFile(join(root, '.gitignore'), '.lazykimi/\n');
  await writeFile(join(root, 'docs/execution-plan.md'), PLAN_DOCUMENT);
  await processCall(['git', '-C', root, 'add', '.gitignore', 'docs'], '', gitEnv);
  await processCall(['git', '-C', root, 'commit', '-qm', 'fixture'], '', gitEnv);
  const created = await processCall(['bash', join(plugin, 'scripts/state/create-run.sh'), 'probe', 'Kimi project probe'],
    '', { CWD: root, ...environment });
  if (created.code) throw new Error(created.stderr);
  const run = join(root, '.lazykimi/runs/probe');
  const head = (await processCall(['git', '-C', root, 'rev-parse', 'HEAD'], '', gitEnv)).stdout.trim();
  await writeFile(join(run, 'waiter.mjs'), WAITER);
  const runPlan = '# Kimi plan\n- [x] [C1] Original Kimi criterion\n';
  const artifact = join(run, 'actual.txt');
  const commands = [[process.execPath, join(run, 'waiter.mjs'), join(run, 'release-killed')],
    [process.execPath, join(host, 'test/workload.mjs'), 'write', artifact, 'Kimi adopted edit'],
    [process.execPath, join(host, 'test/workload.mjs'), 'verify', artifact, 'Kimi adopted edit']];
  const commandsBytes = `${JSON.stringify(commands)}\n`;
  const statePath = join(run, 'state.json');
  const state = JSON.parse(await readFile(statePath, 'utf8'));
  state.status = 'active'; state.plan_reference = '.lazykimi/runs/probe/plan.md'; state.plan_revision = 1;
  state._approved_plan_sha256 = digest(runPlan); state.dashboard_project_id = PROJECT_ID;
  state.human_gates = [{ name: 'release', status: 'pending', result: '' }];
  state.tasks = [{ id: 'P', title: 'Kimi parent', status: 'running', depends_on: [], execution_authority: {
    repo_head: head, criterion_ids: ['C1'], plan_reference: state.plan_reference, plan_sha256: digest(runPlan),
    plan_commands_path: '.lazykimi/runs/probe/commands.json', plan_commands_sha256: digest(commandsBytes),
  } }, { id: 'A', title: 'Kimi child', status: 'queued', depends_on: [], criteria: [{ id: 'C1', task_id: 'A', version: 1,
    requirement: 'Original Kimi criterion', applicability: 'required', verification: 'unverified', scenarios: [], result_ids: [], history: [] }] }];
  await mkdir(join(run, 'checkpoints'), { recursive: true });
  await Promise.all([writeFile(join(run, 'plan.md'), runPlan), writeFile(join(run, 'checkpoints/plan-revision.md'), runPlan),
    writeFile(join(run, 'commands.json'), commandsBytes), writeFile(statePath, JSON.stringify(state))]);
  const binding = ['--project-root', root, '--project-id', PROJECT_ID, '--run-id', 'probe'];
  const producers = (action, extra, input = '') => processCall([process.execPath, join(host, 'producers.mjs'),
    action, ...binding, '--actor', 'test:kimi-producer', ...extra], input, environment);
  const project = (action, extra = [], input = '') => processCall([process.execPath, projectCLI, action,
    ...binding.slice(0, 4), '--actor', ACTOR, ...extra], input, environment);
  return { root, run, statePath, artifact, binding, producers, project,
    cleanup: () => rm(root, { recursive: true, force: true }) };
}

async function context(f, attempt, worker, index) {
  const result = await f.producers('context', ['--parent-task-id', 'P', '--task-id', 'A', '--criterion-id', 'C1',
    '--attempt-id', attempt, '--worker-id', worker, '--plan-commands-file', join(f.run, 'commands.json'),
    '--command-index', String(index)]);
  assert.equal(result.code, 0, result.stderr);
  const path = join(f.run, `${attempt.replace(':', '-')}.json`);
  await writeFile(path, result.stdout);
  return path;
}

function launch(f, args) {
  const child = spawn(process.execPath, [join(host, 'producers.mjs'), ...args], { env: { ...process.env, ...environment } });
  let stdout = ''; let stderr = '';
  child.stdout.on('data', chunk => { stdout += chunk; });
  child.stderr.on('data', chunk => { stderr += chunk; });
  const done = new Promise(resolve => child.on('close', (code, signal) => resolve({ code, signal, stdout, stderr })));
  return { child, done };
}

async function waitForFile(file, timeoutMs = 15000) {
  const deadline = Date.now() + timeoutMs;
  for (;;) {
    try { await stat(file); return; }
    catch { if (Date.now() > deadline) throw new Error(`timed out waiting for ${file}`); }
    await new Promise(resolve => setTimeout(resolve, 25));
  }
}

test('vendored project family matches the pinned vendor manifest byte for byte', async () => {
  const sidecar = JSON.parse(await readFile(join(plugin, 'shared/project.vendor.json'), 'utf8'));
  assert.equal(sidecar.source.repository, 'https://github.com/elvinzhao10/LazyBuddy');
  assert.ok(/^[a-f0-9]{40}$/.test(sidecar.source.revision));
  const files = await tree(join(plugin, 'shared/project'));
  assert.deepEqual(files.slice().sort(), sidecar.files.map(item => item.path).sort());
  for (const record of sidecar.files) {
    const bytes = await readFile(join(plugin, 'shared/project', record.path));
    assert.equal(bytes.length, record.bytes, record.path);
    assert.equal(createHash('sha256').update(bytes).digest('hex'), record.sha256, record.path);
  }
  const stable = sidecar.files.map(item => `${item.path}\0${item.bytes}\0${item.sha256}\n`).join('');
  assert.equal(createHash('sha256').update(stable).digest('hex'), sidecar.source.treeSha256);
});

test('Kimi project record initializes through .lazykimi and links a native run honestly', async () => {
  const f = await projectFixture();
  try {
    const initialized = await f.project('init');
    assert.equal(initialized.code, 0, initialized.stderr);
    const snapshot = JSON.parse(initialized.stdout);
    assert.equal(snapshot.runtime, 'LazyKimi');
    assert.equal(snapshot.revision, 0);
    const owner = JSON.parse(await readFile(join(f.root, '.lazykimi/project/owner.json'), 'utf8'));
    assert.equal(owner.owner, 'LazyKimi/project');
    const registry = JSON.parse(await readFile(join(f.root, '.lazyseries/project.json'), 'utf8'));
    assert.equal(registry.runtime, 'LazyKimi');
    assert.equal(registry.project_id, PROJECT_ID);
    const document = await readFile(join(f.root, 'docs/execution-plan.md'));
    let revision = 0;
    for (const [operation, payload] of [
      ['register_source', { id: 'source:plan', path: 'docs/execution-plan.md', role: 'plan' }],
      ['register_plan', { id: 'plan:exec', source: { source_id: 'source:plan', sha256: digest(document.toString()),
        anchor_id: 'document' }, declared_lifecycle: 'planned', baseline_refs: [] }],
      ['link_native_run', { plan_id: 'plan:exec', native_project_id: PROJECT_ID, run_id: 'probe' }],
    ]) {
      const result = await f.project('command', [], JSON.stringify(command(operation, revision, payload)));
      assert.equal(result.code, 0, result.stderr);
      assert.equal(JSON.parse(result.stdout).receipt.status, 'saved');
      revision += 1;
    }
    const stale = await f.project('command', [], JSON.stringify(command('register_source', 0,
      { id: 'source:again', path: 'docs/execution-plan.md', role: 'plan' }, 'stale:probe')));
    assert.equal(stale.code, 0, stale.stderr);
    assert.equal(JSON.parse(stale.stdout).receipt.status, 'conflict');
    const read = await f.project('read');
    assert.equal(read.code, 0, read.stderr);
    const linked = JSON.parse(read.stdout);
    assert.equal(linked.revision, 3);
    assert.deepEqual(linked.plans[0].native_runs.map(entry => entry.run_id), ['probe']);
    // The link is identity only; the observed execution comes from Kimi's own run store.
    assert.equal(linked.plans[0].native_observations.length, 1);
    assert.equal(linked.plans[0].native_observations[0].runtime, 'LazyKimi');
    assert.equal(linked.plans[0].native_observations[0].execution, 'running');
    assert.equal(linked.sources[0].observation.status, 'current');
  } finally { await f.cleanup(); }
});

test('registered original-source editing preserves fences and unrelated prose (T05 semantics)', async () => {
  const f = await projectFixture();
  try {
    assert.equal((await f.project('init')).code, 0);
    const document = await readFile(join(f.root, 'docs/execution-plan.md'), 'utf8');
    const registered = await f.project('command', [], JSON.stringify(command('register_source', 0,
      { id: 'source:plan', path: 'docs/execution-plan.md', role: 'plan' })));
    assert.equal(JSON.parse(registered.stdout).receipt.status, 'saved');
    const mapped = await f.project('command', [], JSON.stringify(command('source.map', 1, { source_id: 'source:plan' })));
    assert.equal(mapped.code, 0, mapped.stderr);
    const anchor = JSON.parse(mapped.stdout).result.anchors.find(entry => entry.title === 'Tasks');
    assert.ok(anchor, 'the Tasks heading must be mapped');
    const edit = { authority: ACTOR, source_id: 'source:plan', expected_sha256: digest(document),
      expected_source_revision: 1, edits: [{ kind: 'set_task_state', anchor_id: anchor.anchor_id, item: 0, state: 'checked' }] };
    const preview = await f.project('command', [], JSON.stringify(command('source.edit.preview', 1, edit, 'preview:probe')));
    assert.equal(preview.code, 0, preview.stderr);
    const previewResult = JSON.parse(preview.stdout);
    assert.equal(previewResult.result.status, 'valid');
    assert.match(previewResult.result.patch_text, /\[x\] \[C1\] Kimi criterion one/);
    // A preview never writes: the original bytes are untouched.
    assert.equal(await readFile(join(f.root, 'docs/execution-plan.md'), 'utf8'), document);
    const applied = await f.project('command', [], JSON.stringify(command('source.edit', 1, edit)));
    assert.equal(applied.code, 0, applied.stderr);
    assert.equal(JSON.parse(applied.stdout).receipt.status, 'saved');
    const edited = await readFile(join(f.root, 'docs/execution-plan.md'), 'utf8');
    assert.equal(edited, document.replace('- [ ] [C1] Kimi criterion one', '- [x] [C1] Kimi criterion one'));
    // Fenced examples and unrelated prose stay byte-identical (fenced fake items are never touched).
    assert.ok(edited.includes('```bash\necho fenced example stays byte-identical\n```'));
    assert.ok(edited.includes('Intro prose that no edit may touch.'));
    assert.ok(edited.includes('- [ ] [C2] Kimi criterion two'));
    // The journaled CAS transaction completed: no pending edit-journal entry remains.
    const journal = join(f.root, '.lazykimi/project/edit-journal');
    assert.equal((await tree(f.root, '.lazykimi/project/edit-journal')).length, 0);
    assert.ok(await stat(journal).then(() => true, () => false));
    const after = await f.project('read');
    const observed = JSON.parse(after.stdout);
    assert.equal(observed.sources[0].observation.status, 'current');
    assert.equal(observed.sources[0].revision, 2);
  } finally { await f.cleanup(); }
});

test('project telemetry records from Kimi journal/CAS evidence and never invents approvals', async () => {
  const f = await projectFixture();
  try {
    assert.equal((await f.project('init')).code, 0);
    for (const [operation, payload] of [
      ['register_source', { id: 'source:plan', path: 'docs/execution-plan.md', role: 'plan' }],
      ['register_plan', { id: 'plan:exec', source: { source_id: 'source:plan',
        sha256: digest(await readFile(join(f.root, 'docs/execution-plan.md'), 'utf8')), anchor_id: 'document' },
        declared_lifecycle: 'active', baseline_refs: [] }],
      ['link_native_run', { plan_id: 'plan:exec', native_project_id: PROJECT_ID, run_id: 'probe' }],
    ]) {
      const revision = JSON.parse((await f.project('read')).stdout).revision;
      const result = await f.project('command', [], JSON.stringify(command(operation, revision, payload)));
      assert.equal(JSON.parse(result.stdout).receipt.status, 'saved');
    }
    // A producer killed mid-run leaves a dispatched attempt with a start manifest and no terminal.
    const killedContext = await context(f, 'executor:killed', 'worker:kimi-executor', 0);
    const killed = launch(f, ['execute', ...f.binding, '--actor', 'test:kimi-producer',
      '--context-file', killedContext, '--artifact-path', '.lazykimi/runs/probe/killed.txt']);
    await waitForFile(join(f.run, 'producer-attempts', digest('executor:killed'), 'start.json'));
    killed.child.kill('SIGKILL');
    await killed.done;
    await writeFile(join(f.run, 'release-killed'), 'go\n');
    const executorContext = await context(f, 'executor:kimi', 'worker:kimi-executor', 1);
    const executed = await f.producers('execute', ['--context-file', executorContext,
      '--artifact-path', '.lazykimi/runs/probe/actual.txt']);
    assert.equal(executed.code, 0, executed.stderr || executed.stdout);
    const verifierContext = await context(f, 'verifier:kimi', 'worker:kimi-verifier', 2);
    const verified = await f.producers('verify', ['--context-file', verifierContext,
      '--artifact-path', '.lazykimi/runs/probe/actual.txt', '--executor-id', 'worker:kimi-executor',
      '--executor-attempt-id', 'executor:kimi']);
    assert.equal(verified.code, 0, verified.stderr || verified.stdout);

    // Unknown native approval state must survive observation unchanged.
    const gateState = JSON.parse(await readFile(f.statePath, 'utf8'));
    assert.equal(gateState.human_gates[0].status, 'pending');

    const observed = await f.project('observe', ['--run-id', 'probe', '--stale-after-ms', '1000']);
    assert.equal(observed.code, 0, observed.stderr);
    const outcome = JSON.parse(observed.stdout);
    assert.deepEqual(outcome.recorded.sort(), ['observation:attempt:probe:executor:killed',
      'observation:attempt:probe:executor:kimi', 'observation:attempt:probe:verifier:kimi'].sort());
    assert.equal(outcome.snapshot.observation_revision, 3);
    const payloads = new Map(outcome.snapshot.observations.map(record => {
      assert.equal(record.classification, 'observed');
      assert.equal(record.observed_by, ACTIVITY_OBSERVER);
      assert.equal(record.provenance.kind, 'native_event');
      assert.ok(record.provenance.reference.length > 0);
      return [record.id, JSON.parse(record.text)];
    }));
    const killedPayload = payloads.get('observation:attempt:probe:executor:killed');
    assert.equal(killedPayload.activity.state, 'stale');
    assert.equal(killedPayload.activity.liveness, 'unknown');
    assert.equal(killedPayload.activity.interval.end, null);
    assert.equal(killedPayload.activity.interval.end_observed, false);
    assert.deepEqual(killedPayload.delivery.consumption, { status: 'unobserved' });
    for (const id of ['observation:attempt:probe:executor:kimi', 'observation:attempt:probe:verifier:kimi']) {
      const payload = payloads.get(id);
      assert.equal(payload.activity.state, 'finished');
      assert.equal(payload.activity.liveness, 'terminated');
      assert.equal(payload.delivery.dispatch.status, 'published');
      assert.equal(payload.delivery.ack.status, 'observed');
      assert.equal(payload.delivery.consumption.status, 'observed');
      assert.equal(payload.delivery.consumption.result_status, 'pass');
    }
    const executorPayload = payloads.get('observation:attempt:probe:executor:kimi');
    const verifierPayload = payloads.get('observation:attempt:probe:verifier:kimi');
    assert.notEqual(executorPayload.agent.id, verifierPayload.agent.id);
    assert.notEqual(executorPayload.session.id, verifierPayload.session.id);
    for (const payload of payloads.values()) {
      assert.deepEqual(payload.conversational_telemetry, { status: 'unavailable', reason: 'NOT_REPORTED_BY_PRODUCER' });
      assert.equal(payload.activity.live_conversational_agent, false);
      // Telemetry carries delivery facts only: no approval observation exists to misread.
      assert.equal(/approv/i.test(JSON.stringify(payload)), false);
    }
    // The native gate stays exactly as the native authority recorded it.
    const afterGates = JSON.parse(await readFile(f.statePath, 'utf8'));
    assert.deepEqual(afterGates.human_gates, [{ name: 'release', status: 'pending', result: '' }]);
    // Observation recording advances only the observation revision, never the command revision.
    const read = JSON.parse((await f.project('read')).stdout);
    assert.equal(read.observation_revision, 3);
    assert.equal(read.revision, 3);
    // Rebuilding from the same recorded evidence yields identical bytes (no drift, no double-record).
    const rebuilt = await producerAttemptObservations({ projectRoot: f.root, runId: 'probe',
      observedAt: outcome.snapshot.observations[0].observed_at, staleAfterMs: 1000 });
    const rebuiltIds = rebuilt.map(record => record.id).sort();
    assert.deepEqual(rebuiltIds, [...payloads.keys()].sort());
    // A run without recorded evidence fails closed instead of inventing activity.
    await assert.rejects(producerAttemptObservations({ projectRoot: f.root, runId: 'missing',
      observedAt: new Date().toISOString() }), error => error.code === 'ACTIVITY_NOT_OBSERVED');
  } finally {
    await writeFile(join(f.run, 'release-killed'), 'go\n').catch(() => {});
    await f.cleanup();
  }
});

test('pre-initialization project surfaces stay inert with typed hints (IO-1/IO-3)', async () => {
  const root = await realpath(await mkdtemp(join(tmpdir(), 'lazykimi-inert-')));
  try {
    const gitEnv = { GIT_CONFIG_NOSYSTEM: '1', HOME: root, ...environment };
    for (const args of [['init', '-q'], ['config', 'user.name', 'Inert QA'], ['config', 'user.email', 'inert@example.invalid']]) {
      await processCall(['git', '-C', root, ...args], '', gitEnv);
    }
    await writeFile(join(root, '.gitignore'), 'x\n');
    await processCall(['git', '-C', root, 'add', '.gitignore'], '', gitEnv);
    // Detached maintenance must not change the fixture after its baseline is captured.
    await processCall(['git', '-C', root, '-c', 'maintenance.auto=false', 'commit', '-qm', 'fixture'], '', gitEnv);
    const before = await tree(root);
    const read = await processCall([process.execPath, vendoredCLI, 'read',
      '--project-root', root, '--project-id', PROJECT_ID, '--actor', ACTOR], '', environment);
    assert.notEqual(read.code, 0);
    assert.match(read.stderr, /^PROJECT_NOT_INITIALIZED\n$/);
    const tool = await processCall([process.execPath, projectCLI, 'project.context',
      '--project-root', root, '--project-id', PROJECT_ID, '--actor', 'mcp:status-dashboard'], '', environment);
    assert.equal(tool.code, 0, tool.stderr);
    const envelope = JSON.parse(tool.stdout);
    assert.equal(envelope.result.status, 'not_initialized');
    assert.equal(envelope.result.hint, 'PROJECT_NOT_INITIALIZED');
    assert.equal(envelope.result.init_offer.kind, 'question');
    assert.deepEqual(await tree(root), before);
    // The inert tool surface never initializes: only the explicit init route creates the store.
    assert.equal(await stat(join(root, '.lazykimi')).then(() => true, () => false), false);
    assert.equal(await stat(join(root, '.lazyseries')).then(() => true, () => false), false);
  } finally { await rm(root, { recursive: true, force: true }); }
});

test('status-dashboard MCP serves project tools over the Kimi project record', async () => {
  const f = await projectFixture();
  try {
    assert.equal((await f.project('init')).code, 0);
    const document = await readFile(join(f.root, 'docs/execution-plan.md'), 'utf8');
    for (const [operation, payload] of [
      ['register_source', { id: 'source:plan', path: 'docs/execution-plan.md', role: 'plan' }],
      ['register_plan', { id: 'plan:exec', source: { source_id: 'source:plan', sha256: digest(document),
        anchor_id: 'document' }, declared_lifecycle: 'planned', baseline_refs: [] }],
      ['link_native_run', { plan_id: 'plan:exec', native_project_id: PROJECT_ID, run_id: 'probe' }],
    ]) {
      const revision = JSON.parse((await f.project('read')).stdout).revision;
      const result = await f.project('command', [], JSON.stringify(command(operation, revision, payload)));
      assert.equal(JSON.parse(result.stdout).receipt.status, 'saved');
    }
    const revision = JSON.parse((await f.project('read')).stdout).revision;
    const request = (id, name, args) => JSON.stringify({ jsonrpc: '2.0', id, method: 'tools/call',
      params: { name, arguments: args } });
    const session = [
      JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'tools/list' }),
      request(2, 'project', { action: 'project.context', project_id: PROJECT_ID }),
      request(3, 'project', { action: 'project.read', project_id: PROJECT_ID,
        request: { command_id: 'mcp:read:1', expected_revision: revision } }),
      request(4, 'project', { action: 'run.request', project_id: PROJECT_ID,
        request: { command_id: 'mcp:run:1', expected_revision: revision,
          payload: { id: 'request:kimi-mcp', plan_id: 'plan:exec', note: 'recorded through the MCP tool' } } }),
      request(5, 'show_pending_approvals', {}),
    ].join('\n') + '\n';
    const served = await processCall(['/bin/bash', server], session,
      { CWD: f.root, LAZYKIMI_MCP_MODE: 'orchestrated', ...environment });
    assert.equal(served.code, 0, served.stderr);
    const lines = served.stdout.split('\n').filter(Boolean);
    const listing = JSON.parse(lines[0]);
    assert.deepEqual(listing.result.tools.map(tool => tool.name), ['show_run_status', 'show_task_graph',
      'show_verification_matrix', 'show_pending_approvals', 'dashboard_service', 'copy_task_context', 'project']);
    const replies = new Map(lines.slice(1).map(line => {
      const reply = JSON.parse(line);
      assert.equal(reply.error, undefined, line);
      return [reply.id, JSON.parse(reply.result.content[0].text)];
    }));
    const contextReply = replies.get(2);
    assert.equal(contextReply.result.status, 'ok');
    assert.equal(contextReply.result.summary.project.runtime, 'LazyKimi');
    assert.equal(contextReply.result.summary.boundaries.native_approval_observation, 'unobserved');
    const readReply = replies.get(3);
    assert.equal(readReply.result.status, 'ok');
    assert.equal(readReply.result.project_id, PROJECT_ID);
    assert.equal(readReply.delivery.native_delivery, 'unobserved');
    const runReply = replies.get(4);
    // A content operation answers with its retained receipt and post-command snapshot.
    assert.equal(runReply.receipt.status, 'saved');
    assert.equal(runReply.snapshot.requests.length, 1);
    assert.equal(runReply.snapshot.requests[0].delivery, 'unobserved');
    // Unknown native approval state never becomes observed through any project surface.
    const approvals = replies.get(5);
    assert.equal(approvals.status, 'unknown');
    assert.equal(approvals.live_approval_tracking, false);
    assert.deepEqual(approvals.pending, [{ name: 'release', status: 'pending', result: '' }]);
  } finally { await f.cleanup(); }
});

// F-04: the neutral registry is shared across runtimes. A registry another
// runtime owns is foreign state: init refuses typed instead of creating a
// second owner, and the foreign registry stays byte-identical. The foreign
// runtime is any family runtime other than this port's own.
const FOREIGN_RUNTIME = RUNTIMES.find(name => name !== 'LazyKimi');
test('init refuses a registry another runtime owns and never adopts its identity', async () => {
  const f = await projectFixture();
  try {
    const registryPath = join(f.root, '.lazyseries/project.json');
    const foreign = { schema_version: 1, project_id: PROJECT_ID,
      repository_key: `repo:${'ab'.repeat(32)}`, runtime: FOREIGN_RUNTIME,
      created_at: '2026-10-01T00:00:00.000Z',
      sources: [{ id: 'source:plan', role: 'plan', path: 'docs/execution-plan.md' }] };
    await mkdir(join(f.root, '.lazyseries'), { mode: 0o700 });
    await writeFile(registryPath, JSON.stringify(foreign) + '\n', { mode: 0o600 });
    const owned = await readFile(registryPath);
    for (let attempt = 1; attempt <= 2; attempt++) {
      const refused = await f.project('init');
      assert.notEqual(refused.code, 0, `foreign-runtime init attempt ${attempt} must fail closed`);
      assert.equal(refused.stderr.trim(), 'REGISTRY_FOREIGN_RUNTIME');
      assert.equal((await readFile(registryPath)).equals(owned), true,
        'a refused init must leave the foreign registry byte-identical');
    }
    assert.equal(await stat(join(f.root, '.lazykimi/project')).then(() => true, () => false), false,
      'a refused foreign-runtime init creates no second project owner');
    const registry = JSON.parse(await readFile(registryPath, 'utf8'));
    assert.equal(registry.runtime, FOREIGN_RUNTIME);
    assert.equal(registry.sources.length, 1, 'the owning runtime source list stays stable');
  } finally { await f.cleanup(); }
});

// F-04 mirror guard: a matching runtime proceeds normally, and a store that
// already exists refuses to rewrite the pointer list of a foreign registry.
test('matching-runtime init stays idempotent and the source mirror refuses a foreign runtime', async () => {
  const f = await projectFixture();
  try {
    assert.equal((await f.project('init')).code, 0);
    const again = await f.project('init');
    assert.equal(again.code, 0, again.stderr);
    const registered = await f.project('command', [], JSON.stringify(command('register_source', 0,
      { id: 'source:plan', path: 'docs/execution-plan.md', role: 'plan' })));
    assert.equal(JSON.parse(registered.stdout).receipt.status, 'saved');
    const registryPath = join(f.root, '.lazyseries/project.json');
    const mirrored = JSON.parse(await readFile(registryPath, 'utf8'));
    assert.equal(mirrored.runtime, 'LazyKimi');
    assert.deepEqual(mirrored.sources.map(source => source.id), ['source:plan']);
    // Damaged state: the shared registry document is replaced by a foreign
    // runtime's while the store identity stays bound. A further mutation must
    // refuse instead of flapping the foreign source pointer list.
    await writeFile(join(f.root, 'docs/other-plan.md'), '# Other plan\n');
    const flipped = { ...mirrored, runtime: FOREIGN_RUNTIME };
    await writeFile(registryPath, JSON.stringify(flipped) + '\n');
    const foreignBytes = await readFile(registryPath);
    const flapped = await f.project('command', [], JSON.stringify(command('register_source', 1,
      { id: 'source:other', path: 'docs/other-plan.md', role: 'plan' })));
    assert.notEqual(flapped.code, 0, 'a foreign-runtime registry must not be mirrored');
    assert.equal(flapped.stderr.trim(), 'REGISTRY_FOREIGN_RUNTIME');
    assert.equal((await readFile(registryPath)).equals(foreignBytes), true,
      'the refused mirror leaves the foreign registry byte-identical');
  } finally { await f.cleanup(); }
});

test('per-surface capability record claims no observed host adoption', () => {
  for (const [capability, status] of Object.entries(capabilities)) {
    assert.notEqual(status, 'observed', `${capability} must not claim observed host adoption`);
  }
});
