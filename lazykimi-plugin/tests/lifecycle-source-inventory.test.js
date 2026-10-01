'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const {
  LifecycleError,
  prepareProductRoot,
  stageRelease,
} = require('../scripts/lifecycle');

function fixture() {
  const sandbox = fs.mkdtempSync(path.join(fs.realpathSync(os.tmpdir()), 'lazykimi source inventory '));
  const sourceRoot = path.join(sandbox, 'source checkout');
  fs.mkdirSync(path.join(sourceRoot, 'lazykimi-plugin', 'tooling'), { recursive: true });
  fs.writeFileSync(path.join(sourceRoot, 'launcher.js'), "console.log('ok')\n");
  return {
    paths: prepareProductRoot({ installRoot: path.join(sandbox, 'install root'), product: 'LazyKimi' }),
    sandbox,
    sourceRoot,
  };
}

function stage(f) {
  return stageRelease(f.paths, {
    sourceRoot: f.sourceRoot,
    version: '1.2.3',
    commitSha: 'a'.repeat(40),
  });
}

function expectOwnershipRefusal(action) {
  assert.throws(action, (error) => error instanceof LifecycleError && error.code === 'OWNERSHIP_REFUSED');
}

test('stageRelease omits package-manager dependencies without accepting their executable links', (t) => {
  // Given a real npm-owned dependency directory containing a generated .bin symlink.
  const f = fixture();
  t.after(() => fs.rmSync(f.sandbox, { recursive: true }));
  const modules = path.join(f.sourceRoot, 'lazykimi-plugin', 'tooling', 'node_modules');
  const executable = path.join(modules, '@ast-grep', 'cli', 'sg');
  fs.mkdirSync(path.join(modules, '.bin'), { recursive: true });
  fs.mkdirSync(path.dirname(executable), { recursive: true });
  fs.writeFileSync(executable, '#!/bin/sh\nexit 0\n', { mode: 0o755 });
  fs.symlinkSync('../@ast-grep/cli/sg', path.join(modules, '.bin', 'ast-grep'));

  // When the source is staged for a durable release.
  const staged = stage(f);

  // Then transient dependencies are absent from the staged release.
  assert.equal(fs.existsSync(path.join(staged.stagingPath, 'lazykimi-plugin', 'tooling', 'node_modules')), false);
  assert.equal(fs.readFileSync(path.join(staged.stagingPath, 'launcher.js'), 'utf8'), "console.log('ok')\n");
});

test('stageRelease still refuses a user-controlled source link', (t) => {
  // Given a user-controlled link outside the generated dependency subtree.
  const linked = fixture();
  t.after(() => fs.rmSync(linked.sandbox, { recursive: true }));
  fs.symlinkSync(linked.sourceRoot, path.join(linked.sourceRoot, 'caller-link'));

  // When/Then staging inventories the source, it refuses the linked entry.
  expectOwnershipRefusal(() => stage(linked));
});

test('stageRelease excludes only the unchanged hooks bridge to its real canonical directory', t => {
  const f = fixture();
  t.after(() => fs.rmSync(f.sandbox, { recursive: true, force: true }));
  const hooks = path.join(f.sourceRoot, 'lazykimi-plugin/hooks');
  const scripts = path.join(f.sourceRoot, 'lazykimi-plugin/scripts');
  fs.mkdirSync(hooks);
  fs.mkdirSync(scripts);
  fs.writeFileSync(path.join(hooks, 'owned.sh'), 'canonical hook\n');
  fs.symlinkSync('../hooks', path.join(scripts, 'hooks'));
  const staged = stage(f);
  assert.equal(fs.readFileSync(path.join(staged.stagingPath, 'lazykimi-plugin/hooks/owned.sh'), 'utf8'), 'canonical hook\n');
  assert.equal(fs.existsSync(path.join(staged.stagingPath, 'lazykimi-plugin/scripts/hooks')), false);
  assert.equal(fs.lstatSync(path.join(scripts, 'hooks')).isSymbolicLink(), true);
});

test('stageRelease refuses a changed hooks bridge or linked canonical target', t => {
  for (const mutation of ['changed-bridge', 'linked-target']) {
    const f = fixture();
    t.after(() => fs.rmSync(f.sandbox, { recursive: true, force: true }));
    const hooks = path.join(f.sourceRoot, 'lazykimi-plugin/hooks');
    const scripts = path.join(f.sourceRoot, 'lazykimi-plugin/scripts');
    fs.mkdirSync(scripts);
    if (mutation === 'linked-target') fs.symlinkSync(f.sourceRoot, hooks);
    else fs.mkdirSync(hooks);
    fs.symlinkSync(mutation === 'changed-bridge' ? '../tooling' : '../hooks', path.join(scripts, 'hooks'));
    expectOwnershipRefusal(() => stage(f));
  }
});

test('stageRelease refuses a symlink substituted for the dependency root', (t) => {
  // Given the dependency-root pathname itself was substituted with a symlink.
  const substituted = fixture();
  t.after(() => fs.rmSync(substituted.sandbox, { recursive: true }));
  const outside = path.join(substituted.sandbox, 'outside dependencies');
  fs.mkdirSync(outside);
  fs.symlinkSync(outside, path.join(substituted.sourceRoot, 'lazykimi-plugin', 'tooling', 'node_modules'));

  // When/Then the exact omitted boundary must still be a real directory.
  expectOwnershipRefusal(() => stage(substituted));
});
