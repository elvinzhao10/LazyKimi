'use strict';

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const test = require('node:test');
const { prepareProductRoot, promoteRelease, stageRelease } = require('../scripts/lifecycle');

const PLUGIN_ROOT = path.resolve(__dirname, '..');
const SERVERS = ['run-ledger', 'verification', 'status-dashboard', 'context-graph', 'code-intel', 'docs'];

// LazyKimi layout: the staged source root carries the plugin tree as
// lazykimi-plugin/ (with kimi.plugin.json and the single marketplace.json v2
// inside it), not ZCode's plugins/lazyzcode/.zcode-plugin nesting.
function fixture() {
  const sandbox = fs.mkdtempSync(path.join(fs.realpathSync(os.tmpdir()), 'lazykimi-private-receipt-'));
  const sourceRoot = path.join(sandbox, 'source');
  const projectRoot = path.join(sandbox, 'project');
  const installRoot = path.join(sandbox, 'install');
  fs.cpSync(PLUGIN_ROOT, path.join(sourceRoot, 'lazykimi-plugin'), {
    recursive: true,
    // Match Git checkout semantics rather than cpSync's absolute link rewrite.
    verbatimSymlinks: true,
    filter: source => !/(?:^|[\\/])(?:node_modules|__pycache__|\.git)(?:$|[\\/])/.test(path.relative(PLUGIN_ROOT, source)),
  });
  assert.equal(fs.readlinkSync(path.join(sourceRoot, 'lazykimi-plugin/scripts/hooks')), '../hooks');
  fs.mkdirSync(projectRoot);
  const paths = prepareProductRoot({ installRoot, product: 'LazyKimi' });
  const commitSha = 'c'.repeat(40);
  const staged = stageRelease(paths, { sourceRoot, version: '1.3.4', commitSha });
  const promoted = promoteRelease(paths, {
    ...staged,
    commitSha,
    entrypoint: 'lazykimi-plugin/scripts/lazykimi-lifecycle.js',
    manifestRelativePath: 'lazykimi-plugin/kimi.plugin.json',
    origin: 'https://github.com/elvinzhao10/LazyKimi.git',
    runtimePath: process.execPath,
    version: '1.3.4',
  });
  const releaseRoot = path.join(paths.releases, promoted.releaseId);
  const manifest = path.join(releaseRoot, 'lazykimi-plugin', 'kimi.plugin.json');
  return { installRoot, paths, projectRoot, releaseRoot, sandbox, manifest };
}

function receipt(f) {
  return {
    schema_version: 1,
    type: 'kimi-plugin-manifest-full-plugin',
    source: {
      route: 'kimi-plugin-manifest',
      release_root: f.releaseRoot,
      manifest: 'lazykimi-plugin/kimi.plugin.json',
      manifest_sha256: crypto.createHash('sha256').update(fs.readFileSync(f.manifest)).digest('hex'),
      plugin: 'lazykimi',
      version: '1.3.4',
    },
    host: 'kimi',
    build: 'build:current',
    session_id: 'session:current',
    observed_at: new Date().toISOString(),
    capabilities: {
      skill: { id: 'lazy-programming', status: 'loaded' },
      command: { id: 'lazy-status', status: 'loaded' },
      agent: { id: 'lazykimi-verifier', status: 'loaded' },
      hook: { id: 'SessionStart', status: 'loaded' },
      mcp: Object.fromEntries(SERVERS.map((name) => [name, 'connected'])),
    },
  };
}

test('real CLI refuses a private Kimi receipt reached through a public parent symlink', (t) => {
  // Given: a valid current receipt physically below .kimi-code and a public parent-directory symlink to it.
  const f = fixture();
  const privateDirectory = path.join(f.sandbox, '.kimi-code', 'receipts');
  const publicDirectory = path.join(f.sandbox, 'apparently-public');
  fs.mkdirSync(privateDirectory, { recursive: true });
  fs.symlinkSync(privateDirectory, publicDirectory, 'dir');
  fs.writeFileSync(path.join(privateDirectory, 'receipt.json'), `${JSON.stringify(receipt(f))}\n`);
  t.after(() => fs.rmSync(f.sandbox, { recursive: true, force: true }));

  // When: the promoted lifecycle CLI receives only the apparently public spelling.
  const result = spawnSync(process.execPath, [
    f.paths.launcher,
    'status', '--install-root', f.installRoot, '--project', f.projectRoot,
    '--host', 'kimi', '--host-build', 'build:current', '--host-session', 'session:current',
    '--observation-receipt', path.join(publicDirectory, 'receipt.json'), '--json',
  ], { encoding: 'utf8' });
  const output = JSON.parse(result.stdout);

  // Then: canonical private location wins over caller spelling and readiness stays pending.
  assert.notEqual(result.status, 0);
  assert.deepEqual(output.host_readiness, { status: 'pending' });
  assert.equal(output.error.code, 'OBSERVATION_RECEIPT_INVALID');
});
