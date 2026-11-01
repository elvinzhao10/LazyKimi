const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

test('review events update run review state without invalid task statuses or stale replay', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'lazykimi-review-state-'));
  const scripts = path.resolve(__dirname, '../scripts/state');
  const statePath = path.join(root, '.lazykimi/runs/review/state.json');
  const call = (name, args) => spawnSync('bash', [path.join(scripts, name), ...args], {
    env: { ...process.env, CWD: root }, encoding: 'utf8', timeout: 15000,
  });
  const ok = (name, args) => { const result = call(name, args); assert.equal(result.status, 0, result.stderr); };
  try {
    ok('create-run.sh', ['review', 'Review state fixture']);
    const state = JSON.parse(fs.readFileSync(statePath));
    state.tasks = [{ id: 'T1', title: 'Actual task', status: 'done', depends_on: [] }];
    fs.writeFileSync(statePath, JSON.stringify(state));
    const accepted = JSON.stringify({ event_id: 'review:accept', verdict: 'accept', reviewer_agent_id: 'reviewer:one' });
    ok('append-event.sh', ['review', 'review_verdict', accepted]);
    assert.equal(JSON.parse(fs.readFileSync(statePath)).review_status, 'accepted');
    ok('append-event.sh', ['review', 'review_verdict', JSON.stringify({ event_id: 'review:revise', verdict: 'revise' })]);
    ok('append-event.sh', ['review', 'review_verdict', accepted]);
    const before = fs.readFileSync(statePath);
    assert.equal(JSON.parse(before).review_status, 'revise');
    for (const args of [['review', 'T1', 'review'], ['review', 'T1', 'done', 'status=review'], ['review', 'T1', 'done', 'id=other']]) {
      assert.notEqual(call('update-task.sh', args).status, 0);
      assert.deepEqual(fs.readFileSync(statePath), before);
    }
    assert.equal(JSON.parse(before).tasks[0].status, 'done');
    assert.notEqual(call('append-event.sh', ['review', 'review_verdict', '{"verdict":"invented"}']).status, 0);
    assert.deepEqual(fs.readFileSync(statePath), before);
  } finally { fs.rmSync(root, { recursive: true, force: true }); }
});

test('verification rejects Python 3.10 before importing Python 3.11 runner APIs', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'lazykimi-python-floor-'));
  const python = path.join(root, 'python310');
  try {
    fs.writeFileSync(python, '#!/bin/sh\nif [ "$1" = "-c" ]; then printf "3 10\\n"; exit 0; fi\nexit 97\n', { mode: 0o755 });
    const result = spawnSync('bash', [path.resolve(__dirname, '../scripts/lazykimi-verify.sh')], {
      env: { ...process.env, LAZYKIMI_PYTHON: python }, encoding: 'utf8', timeout: 10000,
    });
    assert.equal(result.status, 2);
    assert.match(result.stderr, /requires Python 3\.11 or newer/);
  } finally { fs.rmSync(root, { recursive: true, force: true }); }
});
