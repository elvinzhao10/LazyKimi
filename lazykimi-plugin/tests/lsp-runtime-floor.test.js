'use strict';
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const root = path.resolve(__dirname, '..');

test('capability metadata matches the locked TypeScript provider', () => {
  const capabilities = JSON.parse(fs.readFileSync(path.join(root, 'tooling/capabilities.json'), 'utf8'));
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'tooling/lsp/typescript/package.json'), 'utf8'));
  const provider = capabilities.capabilities.semantic_navigation.find(entry => entry.command === 'typescript-language-server');
  assert.deepEqual(provider.fallback_packages, Object.entries(manifest.dependencies).map(([name, version]) => `${name}@${version}`).reverse());
});

for (const version of ['20.0.0', '22.22.1', '22.22.2', '22.23.0', '23.0.0', '24.0.0']) {
  for (const command of !['20.0.0', '22.22.1'].includes(version) ? ['lsp-status'] : ['lsp-status', 'lsp-install']) {
    test(`${command} checks the TypeScript provider runtime at ${version}`, () => {
      const tmp = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), 'lazykimi-floor-')));
      try {
        fs.writeFileSync(path.join(tmp, 'test.ts'), 'export const value = 1;\n');
        const binary = path.join(tmp, 'node');
        const realNode = process.execPath.replace(/'/g, "'\\''");
        fs.writeFileSync(binary, `#!/bin/sh\nexec '${realNode}' -p "Object.defineProperty(process.versions, 'node', {value: '${version}'}); $2"\n`, { mode: 0o755 });
        const result = spawnSync('bash', [path.join(root, 'scripts/lazykimi-tooling.sh'), command, '--target', tmp, '--tooling-root', path.join(tmp, 'tooling')], { encoding: 'utf8', env: { ...process.env, PATH: `${tmp}:${process.env.PATH}` } });
        assert.equal(result.status, 0, result.stderr);
        if (!['20.0.0', '22.22.1'].includes(version)) assert.doesNotMatch(result.stdout, /STATE: incompatible/);
        else assert.match(result.stdout, /STATE: incompatible\nLANGUAGE: typescript\nREASON: typescript-language-server@6\.0\.0 requires Node\.js 22\.22\.2 or newer/);
      } finally {
        fs.rmSync(tmp, { recursive: true, force: true });
      }
    });
  }
}
