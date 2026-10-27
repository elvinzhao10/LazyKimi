import test from 'node:test';
import assert from 'node:assert/strict';
import { request } from 'node:http';
import { readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { fixture } from './fixture.mjs';
import { listen } from '../service-http.mjs';

function http(origin, route, headers = {}, body) {
  return new Promise((resolve, reject) => {
    const data = body === undefined ? undefined : JSON.stringify(body);
    const call = request(origin + route, { method: data ? 'POST' : 'GET',
      headers: { origin, ...headers, ...(data ? { 'content-type': 'application/json' } : {}) } }, response => {
      let text = ''; response.on('data', chunk => { text += chunk; });
      response.on('end', () => { let value; try { value = JSON.parse(text); } catch { value = text; } resolve({ status: response.statusCode, value }); });
    });
    call.on('error', reject); call.end(data);
  });
}

test('bound run identity mismatch rejects run data and degrades telemetry', async () => {
  const f = await fixture(); const credential = 'b'.repeat(64);
  let live;
  try {
    assert.equal((await f.call('project.mjs', 'init', [])).code, 0);
    const initialState = JSON.parse(await readFile(f.statePath, 'utf8'));
    initialState.tasks[0].evidence = ['proof.txt'];
    await writeFile(join(f.root, 'proof.txt'), 'bound evidence');
    await writeFile(f.statePath, JSON.stringify(initialState));
    live = await listen({ port: 0, projectRoot: f.root, projectId: 'project:kimi', runId: 'probe' },
      { credential, identity: { instance: 'binding', port: 0 } });
    const session = await http(live.origin, '/api/session', { 'x-dashboard-bootstrap': credential }, {});
    const auth = { authorization: `Bearer ${session.value.token}` };
    const valid = await http(live.origin, '/api/snapshot', auth);
    assert.equal(valid.status, 200);
    const evidenceId = valid.value.evidence.find(item => item.path === 'proof.txt').id;
    assert.equal((await http(live.origin, `/api/evidence/${evidenceId}`, auth)).status, 200);
    const state = JSON.parse(await readFile(f.statePath, 'utf8'));
    state.run_id = 'replacement'; await writeFile(f.statePath, JSON.stringify(state));
    for (const route of ['/api/snapshot', `/api/evidence/${evidenceId}`]) {
      const result = await http(live.origin, route, auth);
      assert.equal(result.status, 422, route);
      assert.equal(JSON.stringify(result.value).includes('replacement'), false, route);
    }
    const telemetry = await http(live.origin, '/api/project/telemetry', auth);
    assert.equal(telemetry.status, 200);
    assert.equal(telemetry.value.run_id, null);
    assert.equal(JSON.stringify(telemetry.value).includes('replacement'), false);
    assert.match(JSON.stringify(telemetry.value), /identity mismatch/);
  } finally { if (live) await live.close(); await f.cleanup(); }
});
