'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const test = require('node:test');

const PLUGIN_ROOT = path.resolve(__dirname, '..');
const CONTRACT = 'contracts/marketplace-route-contract.v1.json';

function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'lazykimi-inventory-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const plugin = path.join(root, 'lazykimi-plugin');
  fs.mkdirSync(plugin);
  for (const relative of ['.kimi-code', 'commands', 'agents', 'hooks', 'mcp', 'scripts', 'contracts', 'kimi.plugin.json', 'marketplace.json']) {
    fs.cpSync(path.join(PLUGIN_ROOT, relative), path.join(plugin, relative), {
      recursive: true,
      filter: (file) => path.basename(file) !== '__pycache__' && !file.endsWith('.pyc'),
    });
  }
  return { root, plugin };
}

function run(fixture, command) {
  return spawnSync(process.execPath, [
    path.join(fixture.plugin, 'scripts', `lazykimi-${command}.js`), fixture.root,
  ], { encoding: 'utf8', timeout: 15000 });
}

function artifacts(fixture) {
  return [CONTRACT, `${CONTRACT}.sha256`].map((relative) => fs.readFileSync(path.join(fixture.plugin, relative), 'utf8'));
}

test('generator preserves contract bytes and counts across caches and repeated runs', (t) => {
  // Given: matching clean and cache-contaminated release trees, including a cache under skills.
  const clean = fixture(t);
  const cached = fixture(t);
  const expected = artifacts(clean);
  for (const relative of ['mcp/__pycache__/server.pyc', 'mcp/loose.pyc', '.kimi-code/skills/__pycache__/skill.pyc']) {
    const file = path.join(cached.plugin, relative);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, 'disposable bytecode');
  }

  // When: the actual generator executes twice per tree.
  const results = [clean, clean, cached, cached].map((copy) => {
    const generated = run(copy, 'regenerate-marketplace-contract');
    return { generated, artifacts: artifacts(copy), checked: run(copy, 'marketplace-route-check') };
  });

  // Then: canonical bytes, counts, ordering and route acceptance are unchanged.
  for (const result of results) {
    assert.equal(result.generated.status, 0, result.generated.stderr);
    assert.equal(result.generated.stdout, results[0].generated.stdout);
    assert.deepEqual(result.artifacts, expected);
    assert.equal(result.checked.status, 0, result.checked.stderr);
  }
});

for (const [kind, relative] of [
  ['symlink', 'mcp/foreign'],
  ['hardlink', 'mcp/foreign'],
  ['symlink', 'mcp/foreign.pyc'],
  ['hardlink', 'mcp/foreign.pyc'],
  ['symlink', 'mcp/.gitkeep'],
  ['symlink', 'mcp/__pycache__/foreign.pyc'],
  ['hardlink', 'mcp/__pycache__/foreign.pyc'],
  ['directory-link', 'mcp/__pycache__'],
  ['directory-link', 'mcp'],
  ['directory-link', '.kimi-code'],
  ['symlink', '.kimi-code/mcp.json'],
  ['hardlink', '.kimi-code/mcp.json'],
]) {
  test(`generator and route checker refuse ${kind} at ${relative}`, (t) => {
    // Given: an external file or tree linked into the canonical payload.
    const copy = fixture(t);
    const external = path.join(copy.root, 'external');
    fs.mkdirSync(external);
    const sentinel = path.join(external, 'sentinel');
    fs.writeFileSync(sentinel, 'external bytes');
    const target = path.join(copy.plugin, relative);
    fs.mkdirSync(path.dirname(target), { recursive: true });
    if (fs.existsSync(target)) fs.renameSync(target, path.join(external, 'original'));
    if (kind === 'hardlink') fs.linkSync(sentinel, target);
    else fs.symlinkSync(kind === 'directory-link' ? external : sentinel, target);
    const before = artifacts(copy);

    // When: both real package entry points encounter the linked payload.
    const results = ['regenerate-marketplace-contract', 'marketplace-route-check'].map((command) => run(copy, command));

    // Then: both fail closed without successful output or artifact/external mutations.
    for (const result of results) {
      assert.notEqual(result.status, 0);
      assert.equal(result.stdout, '');
      assert.match(result.stderr, /MARKETPLACE_PAYLOAD_INVALID/);
    }
    assert.deepEqual(artifacts(copy), before);
    assert.equal(fs.readFileSync(sentinel, 'utf8'), 'external bytes');
  });
}

test('generator includes ordinary payload edits instead of hiding them as caches', (t) => {
  // Given: an edited payload plus filenames adjacent to the cache exclusion patterns.
  const copy = fixture(t);
  const files = ['mcp/cache.py', 'mcp/__pycache__-source/data', 'mcp/data.pyc.txt'];
  for (const relative of files) {
    fs.mkdirSync(path.dirname(path.join(copy.plugin, relative)), { recursive: true });
    fs.writeFileSync(path.join(copy.plugin, relative), 'caller content');
  }
  const prior = JSON.parse(artifacts(copy)[0]);
  assert.notEqual(run(copy, 'marketplace-route-check').status, 0);

  // When: the generator explicitly refreshes the inventory.
  const result = run(copy, 'regenerate-marketplace-contract');

  // Then: added files are accounted for and accepted without rewriting caller bytes.
  assert.equal(result.status, 0, result.stderr);
  assert.equal(JSON.parse(result.stdout).file_count, prior.payload.file_count + files.length);
  assert.notEqual(JSON.parse(result.stdout).inventory_sha256, prior.payload.inventory_sha256);
  assert.equal(run(copy, 'marketplace-route-check').status, 0);
  for (const relative of files) assert.equal(fs.readFileSync(path.join(copy.plugin, relative), 'utf8'), 'caller content');
});
