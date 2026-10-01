'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const test = require('node:test');
const plugin = path.resolve(__dirname, '..');
const adapter = path.join(plugin, 'scripts/kimi-project-mcp.js');

test('Given a manifest-managed cwd and injected CWD When MCP starts without binding Then no package state is accessed', () => {
  const result = spawnSync(process.execPath, [adapter, 'run-ledger'], { cwd: plugin, env: { ...process.env, CWD: plugin }, encoding: 'utf8', input: '' });
  assert.equal(result.status, 2);
  assert.equal(result.stdout, '');
  assert.match(result.stderr, /explicit project binding required/);
});

test('Given explicit project binding When MCP initializes Then it answers from the bound project outside plugin cwd', t => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'kimi-native-project-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const result = spawnSync(process.execPath, [adapter, 'run-ledger', '--project', root], { cwd: plugin, encoding: 'utf8', input: '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}\n', timeout: 10000 });
  assert.equal(result.status, 0, result.stderr);
  const reply = JSON.parse(result.stdout.trim());
  assert.equal(reply.id, 1);
  assert.ok(reply.result.serverInfo);
});

test('Given two configured projects and hostile host env When the adapter launches Then each process receives its own bound root', t => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'kimi-native-binding-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const packageRoot = path.join(root, 'package');
  fs.mkdirSync(path.join(packageRoot, 'scripts'), { recursive: true });
  fs.mkdirSync(path.join(packageRoot, 'mcp/run-ledger'), { recursive: true });
  fs.copyFileSync(adapter, path.join(packageRoot, 'scripts/kimi-project-mcp.js'));
  fs.writeFileSync(path.join(packageRoot, 'mcp/run-ledger/server.sh'), 'printf "%s\\n" "$PWD" "$CWD" "$LAZYKIMI_MCP_MODE"\n');
  for (const name of ['project-a', 'project-b']) {
    const project = path.join(root, name);
    fs.mkdirSync(project);
    const result = spawnSync(process.execPath, [path.join(packageRoot, 'scripts/kimi-project-mcp.js'), 'run-ledger', '--project', project, '--mode', 'direct'], {
      cwd: packageRoot, env: { ...process.env, CWD: packageRoot, KIMI_PLUGIN_ROOT: packageRoot }, encoding: 'utf8',
    });
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(result.stdout.trim().split('\n'), [fs.realpathSync(project), fs.realpathSync(project), 'direct']);
  }
});
