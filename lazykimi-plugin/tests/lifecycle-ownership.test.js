'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const { spawnSync } = require('node:child_process');
const test = require('node:test');
const cli = path.resolve(__dirname, '../dist/index.js');
function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'kimi-ownership-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  fs.mkdirSync(path.join(root, '.kimi-code'));
  return root;
}
function run(root, args) {
  return spawnSync(process.execPath, [cli, ...args], { cwd: root, encoding: 'utf8', timeout: 30000, env: { ...process.env, HOME: root, KIMI_CODE_HOME: path.join(root, 'isolated-host') } });
}
function receipt(files) { return { version: 1, installedAt: '2026-09-30', pluginVersion: 'fixture', files }; }
function entry(relative, text) { return { path: relative, sha256: crypto.createHash('sha256').update(text).digest('hex'), size: Buffer.byteLength(text) }; }

test('Given absent empty malformed and hostile receipts When uninstall runs Then every user asset survives', async t => {
  const cases = [undefined, '{}', 'bad json', JSON.stringify(receipt([])),
    JSON.stringify({ ...receipt([entry('.kimi-code/user.md', 'user')]), version: 999 }),
    JSON.stringify(receipt([{ path: '.kimi-code/user.md', sha256: 'invalid', size: 4 }])),
    JSON.stringify(receipt([entry('/absolute.txt', 'user')])),
    JSON.stringify(receipt([entry('../outside.txt', 'user')])),
    JSON.stringify(receipt([entry('.kimi-code/user.md', 'user'), entry('.kimi-code/user.md', 'user')]))];
  for (const raw of cases) await t.test(String(raw), st => {
    const root = fixture(st);
    fs.writeFileSync(path.join(root, '.kimi-code/user.md'), 'user');
    if (raw !== undefined) fs.writeFileSync(path.join(root, '.kimi-code/.lazykimi-receipt.json'), raw);
    const result = run(root, ['uninstall', '--yes', '--purge-state']);
    assert.equal(result.status, 0, result.stderr);
    assert.equal(fs.readFileSync(path.join(root, '.kimi-code/user.md'), 'utf8'), 'user');
  });
});

test('Given an owned receipt with a symlinked parent or hardlinked file When uninstall runs Then no linked asset is removed', async t => {
  for (const kind of ['symlink-parent', 'hardlink']) await t.test(kind, st => {
    const root = fixture(st);
    fs.mkdirSync(path.join(root, 'outside'));
    fs.writeFileSync(path.join(root, 'outside/file.md'), 'user');
    const rel = kind === 'hardlink' ? '.kimi-code/file.md' : '.kimi-code/linked/file.md';
    if (kind === 'hardlink') fs.linkSync(path.join(root, 'outside/file.md'), path.join(root, rel));
    else fs.symlinkSync(path.join(root, 'outside'), path.join(root, '.kimi-code/linked'));
    fs.writeFileSync(path.join(root, '.kimi-code/.lazykimi-receipt.json'), JSON.stringify(receipt([entry(rel, 'user')])));
    assert.equal(run(root, ['uninstall', '--yes']).status, 0);
    assert.equal(fs.readFileSync(path.join(root, rel), 'utf8'), 'user');
  });
});

test('Given an unknown LazyKimi MCP key and linked receipt When init runs Then neither is adopted or overwritten', t => {
  const root = fixture(t);
  const config = { mcpServers: { 'lazykimi-docs': { command: 'user-docs' }, foreign: { command: 'foreign' } } };
  fs.writeFileSync(path.join(root, '.kimi-code/mcp.json'), JSON.stringify(config));
  const outside = path.join(root, 'caller-receipt');
  fs.writeFileSync(outside, 'caller-owned');
  fs.symlinkSync(outside, path.join(root, '.kimi-code/.lazykimi-receipt.json'));
  assert.equal(run(root, ['init']).status, 0);
  assert.deepEqual(JSON.parse(fs.readFileSync(path.join(root, '.kimi-code/mcp.json'))).mcpServers['lazykimi-docs'], config.mcpServers['lazykimi-docs']);
  assert.equal(fs.readFileSync(outside, 'utf8'), 'caller-owned');
});

test('Given one owned asset and a linked later entry When uninstall runs Then receipt preflight prevents partial deletion', t => {
  const root = fixture(t);
  fs.writeFileSync(path.join(root, '.kimi-code/owned.md'), 'owned');
  fs.writeFileSync(path.join(root, 'outside.md'), 'outside');
  fs.symlinkSync(path.join(root, 'outside.md'), path.join(root, '.kimi-code/linked.md'));
  fs.writeFileSync(path.join(root, '.kimi-code/.lazykimi-receipt.json'), JSON.stringify(receipt([entry('.kimi-code/owned.md', 'owned'), entry('.kimi-code/linked.md', 'outside')])));
  assert.equal(run(root, ['uninstall', '--yes']).status, 0);
  assert.equal(fs.readFileSync(path.join(root, '.kimi-code/owned.md'), 'utf8'), 'owned');
  assert.equal(fs.readFileSync(path.join(root, 'outside.md'), 'utf8'), 'outside');
});

test('Given existing project assets When init and reinit run Then user MCP and modified files and state survive', t => {
  const root = fixture(t);
  fs.writeFileSync(path.join(root, '.kimi-code/AGENTS.md'), 'user instructions');
  fs.writeFileSync(path.join(root, '.kimi-code/mcp.json'), JSON.stringify({ extra: 7, mcpServers: { foreign: { command: 'user-server' } } }));
  assert.equal(run(root, ['init']).status, 0);
  const state = path.join(root, '.lazykimi/state/boulder.json');
  fs.writeFileSync(state, 'active user state');
  const hook = path.join(root, '.kimi-code/hooks/stop-gate.sh');
  fs.writeFileSync(hook, 'modified user hook');
  assert.equal(run(root, ['init', '--mcp-mode', 'direct']).status, 0);
  assert.equal(fs.readFileSync(state, 'utf8'), 'active user state');
  assert.equal(fs.readFileSync(hook, 'utf8'), 'modified user hook');
  assert.equal(fs.readFileSync(path.join(root, '.kimi-code/AGENTS.md'), 'utf8'), 'user instructions');
  let config = JSON.parse(fs.readFileSync(path.join(root, '.kimi-code/mcp.json')));
  assert.deepEqual(config.mcpServers.foreign, { command: 'user-server' });
  assert.equal(config.extra, 7);
  assert.equal(config.mcpServers['lazykimi-run-ledger'].args.includes(fs.realpathSync(root)), true);
  assert.equal(run(root, ['uninstall', '--yes']).status, 0);
  config = JSON.parse(fs.readFileSync(path.join(root, '.kimi-code/mcp.json')));
  assert.deepEqual(Object.keys(config.mcpServers), ['foreign']);
});

test('Given KIMI_CODE_HOME When host config path resolves Then the override is authoritative', () => {
  const result = spawnSync(process.execPath, ['-e', `console.log(require(${JSON.stringify(path.resolve(__dirname, '../dist/lib/paths.js'))}).getKimiConfigFile())`], { encoding: 'utf8', env: { ...process.env, KIMI_CODE_HOME: '/isolated-kimi-home' } });
  assert.equal(result.stdout.trim(), '/isolated-kimi-home/config.toml');
});

test('Given modified owned assets When sync refreshes its receipt Then uninstall still preserves the modifications and selected mode', t => {
  const root = fixture(t);
  assert.equal(run(root, ['init', '--mcp-mode', 'direct']).status, 0);
  const file = path.join(root, '.kimi-code/AGENTS.md');
  fs.appendFileSync(file, '\nuser addition\n');
  const modified = fs.readFileSync(file, 'utf8');
  assert.equal(run(root, ['sync']).status, 0);
  assert.equal(JSON.parse(fs.readFileSync(path.join(root, '.kimi-code/.lazykimi-receipt.json'))).pluginVersion, '1.3.4');
  const config = JSON.parse(fs.readFileSync(path.join(root, '.kimi-code/mcp.json')));
  assert.equal(config.mcpServers['lazykimi-run-ledger'].args.at(-1), 'direct');
  assert.equal(run(root, ['uninstall', '--yes']).status, 0);
  assert.equal(fs.readFileSync(file, 'utf8'), modified);
});

test('Given a target containing quotes and replacement tokens When init binds MCP Then JSON paths preserve the exact target', t => {
  const root = fixture(t);
  const target = path.join(root, 'quoted-"-$&-project');
  assert.equal(run(root, ['init', '--target', target]).status, 0);
  const config = JSON.parse(fs.readFileSync(path.join(target, '.kimi-code/mcp.json')));
  assert.equal(config.mcpServers['lazykimi-run-ledger'].args[3], path.resolve(target));
});
