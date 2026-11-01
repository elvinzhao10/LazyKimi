const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const cli = path.resolve(__dirname, '../dist/index.js');

function project(t, scripts) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'lazykimi-verify-diagnostics-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const initialized = spawnSync(process.execPath, [cli, 'init', '--target', root], { encoding: 'utf8' });
  assert.equal(initialized.status, 0, initialized.stderr);
  fs.mkdirSync(path.join(root, 'tests'));
  for (const [name, source] of Object.entries(scripts)) {
    fs.writeFileSync(path.join(root, 'tests', name), source);
  }
  return root;
}

function verify(root) {
  return spawnSync(process.execPath, [cli, 'verify', '--must-pass'], { cwd: root, encoding: 'utf8' });
}

function failure(result) {
  const line = result.stderr.split('\n').find(value => value.startsWith('REGRESSION_FAILURE '));
  assert.ok(line, `missing failed-child diagnostic: ${result.stdout}${result.stderr}`);
  return JSON.parse(line.slice('REGRESSION_FAILURE '.length));
}

test('verify exposes bounded child output and exit status when a regression fails', t => {
  // Given a noisy failure and a later passing regression.
  const root = project(t, {
    'a-failure.sh': 'printf "STDOUT_HEAD\\n"; printf "%06000d" 0; printf "STDOUT_TAIL\\n"\nprintf "STDERR_HEAD\\n" >&2; printf "%06000d" 0 >&2; printf "STDERR_TAIL\\n" >&2\nexit 17\n',
    'b-success.sh': 'printf "SUCCESS_OUTPUT\\n"\n: > continued\n',
  });
  // When the real CLI verifies the project.
  const result = verify(root);
  // Then failure details survive, remain bounded, and do not change suite execution.
  assert.equal(result.status, 1);
  const detail = failure(result);
  assert.equal(detail.script, 'a-failure.sh');
  assert.equal(detail.status, 17);
  assert.equal(detail.signal, null);
  assert.ok(detail.stdoutTail.length <= 4096);
  assert.ok(detail.stderrTail.length <= 4096);
  assert.match(detail.stdoutTail, /STDOUT_TAIL/);
  assert.match(detail.stderrTail, /STDERR_TAIL/);
  assert.doesNotMatch(result.stderr, /STDOUT_HEAD|STDERR_HEAD|SUCCESS_OUTPUT/);
  assert.match(result.stdout, /1 passed, 1 failed/);
  assert.ok(fs.existsSync(path.join(root, 'continued')));
});

test('verify exposes the signal when a regression is terminated', t => {
  // Given a regression that terminates its own shell.
  const root = project(t, { 'signal.sh': 'kill -TERM $$\n' });
  // When the real CLI verifies the project.
  const result = verify(root);
  // Then the failure remains blocking and names the signal.
  assert.equal(result.status, 1);
  const detail = failure(result);
  assert.equal(detail.status, null);
  assert.equal(detail.signal, 'SIGTERM');
});

test('verify remains quiet and ready when regressions pass', t => {
  // Given a successful regression with stdout and stderr.
  const root = project(t, { 'success.sh': 'echo SUCCESS_STDOUT; echo SUCCESS_STDERR >&2\n' });
  // When the real CLI verifies the project.
  const result = verify(root);
  // Then successful output stays suppressed and the existing verdict is unchanged.
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.equal(result.stderr, '');
  assert.doesNotMatch(result.stdout, /SUCCESS_STDOUT|SUCCESS_STDERR/);
  assert.match(result.stdout, /Overall: READY/);
});
