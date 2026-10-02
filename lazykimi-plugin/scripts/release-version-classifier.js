'use strict';

// Release-version classifier for the LazyKimi v1.3.4 family-parity port.
// Ported from lazyzcode v1.3.4 scripts/release-version-classifier.js and
// adapted to the lazykimi layout (single lazykimi-plugin/ tree, kimi.plugin.json
// manifest, and both 0.x and 1.3.x previous-version history).

const fs = require('node:fs');
const path = require('node:path');

const RELEASE_VERSION = '1.3.5';
const PREVIOUS_VERSIONS = ['0.2.0', '0.3.0', '1.3.4'];
const VERSION_JSON_PATHS = [
  ['lazykimi-plugin/kimi.plugin.json', ['version']],
  ['lazykimi-plugin/package.json', ['version']],
  // marketplace.json keeps the Kimi v2 marketplace shape, which carries the
  // spec version only; the single plugin entry identifies by id, not version.
  ['lazykimi-plugin/marketplace.json', ['plugins', 0, 'id']],
  ['lazykimi-plugin/tooling/package.json', ['version']],
  ['lazykimi-plugin/tooling/package-lock.json', ['version']],
  ['lazykimi-plugin/tooling/package-lock.json', ['packages', '', 'version']],
  ['lazykimi-plugin/tooling/lsp/python/package.json', ['version']],
  ['lazykimi-plugin/tooling/lsp/python/package-lock.json', ['version']],
  ['lazykimi-plugin/tooling/lsp/python/package-lock.json', ['packages', '', 'version']],
  ['lazykimi-plugin/tooling/lsp/typescript/package.json', ['version']],
  ['lazykimi-plugin/tooling/lsp/typescript/package-lock.json', ['version']],
  ['lazykimi-plugin/tooling/lsp/typescript/package-lock.json', ['packages', '', 'version']],
  ['lazykimi-plugin/contracts/marketplace-route-contract.v1.json', ['version']],
];
const REQUIRED_RELEASE_NOTE_SECTIONS = [
  'Eval-driven fixes', 'Measured efficiency', 'Host capability matrix',
  'Migration and upgrade', 'Known risks', 'Rollback',
];

function readJson(root, relativePath) {
  return JSON.parse(fs.readFileSync(path.join(root, relativePath), 'utf8'));
}

function nestedValue(value, keys) {
  let current = value;
  for (const key of keys) current = current?.[key];
  return current;
}

function walk(root, directory = root) {
  const files = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    if (entry.name === '.git' || entry.name === '.kimi-code' || entry.name === '.lazykimi'
      || entry.name === 'node_modules' || entry.name === 'dist' || entry.name === 'sources'
      || entry.name.startsWith('.git')) continue;
    const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) files.push(...walk(root, absolute));
    else if (entry.isFile()) files.push(path.relative(root, absolute).split(path.sep).join('/'));
  }
  return files;
}

function previousVersionClassification(relativePath, line) {
  if (relativePath.startsWith('lazykimi-plugin/docs/history/')) return 'historical-release-history';
  if (relativePath === 'RELEASE_NOTES.md') return 'historical-migration-reference';
  if (relativePath === 'lazykimi-plugin/CHANGELOG.md') return 'historical-release-history';
  if (relativePath === 'lazykimi-evaluation.md') return 'labeled-historical-evaluation';
  if (relativePath === 'AGENTS.md' || relativePath === 'CONTRIBUTING.md' || relativePath === 'README.md') return 'historical-migration-reference';
  if (relativePath.includes('/contracts/fixtures/') || relativePath.includes('/tests/fixtures/')) return 'historical-or-adversarial-fixture';
  if (relativePath.includes('automatic-tooling-contract.v1') || relativePath.includes('lazyseries-shared-semantics.v1')
    || relativePath.includes('paired-candidate') || relativePath.includes('paired-live-test')) return 'schema-independent-contract-history';
  if (relativePath.endsWith('release-version-classifier.js')) return 'classifier-input';
  if (/(?:^|\/)(?:test|tests)\//.test(relativePath)) return 'historical-test-input';
  if (/\bcurrent\b.*\b(?:release|version)\b/i.test(line)) return 'current-version-drift';
  if (/(upgrade|migrat|rollback|previous|historical|prior|old release|published|candidate|stable reference|new in|documentation boundary|supported route|major workflow|dual-entry|bootstrap v?0\.[23]\.[0-9]|since v?0\.[23]\.[0-9]|from v?0\.[23]\.[0-9]|tag\/v0\.[23]\.[0-9]|release notes|0\.x)/i.test(line)) return 'historical-migration-reference';
  return 'historical-version-reference';
}

function classify(root) {
  const failures = [];
  const classifications = [];
  for (const [relativePath, keys] of VERSION_JSON_PATHS) {
    let actual;
    try {
      actual = nestedValue(readJson(root, relativePath), keys);
    } catch {
      failures.push(`MISSING_VERSION_FILE ${relativePath}`);
      continue;
    }
    if (actual !== (relativePath.endsWith('marketplace.json') ? 'lazykimi' : RELEASE_VERSION)) {
      failures.push(`CURRENT_VERSION_DRIFT ${relativePath}#${keys.join('.')} expected ${RELEASE_VERSION}, got ${JSON.stringify(actual)}`);
    }
  }
  const runtimeVersion = require(path.join(root, 'lazykimi-plugin/scripts/lifecycle/version.js')).CURRENT_VERSION;
  if (runtimeVersion !== RELEASE_VERSION) failures.push(`PACKAGE_RUNTIME_MISMATCH runtime expected ${RELEASE_VERSION}, got ${runtimeVersion}`);

  const notesPath = path.join(root, 'RELEASE_NOTES.md');
  if (!fs.existsSync(notesPath)) failures.push('MISSING_RELEASE_NOTE RELEASE_NOTES.md');
  else {
    const notes = fs.readFileSync(notesPath, 'utf8');
    if (!notes.startsWith(`# ${'LazyKimi'} v${RELEASE_VERSION}`)) failures.push('CURRENT_VERSION_DRIFT_TEXT RELEASE_NOTES.md:1');
    const currentNotes = notes.split('## Prior release notes')[0];
    for (const section of REQUIRED_RELEASE_NOTE_SECTIONS) {
      if (!currentNotes.includes(`## ${section}`)) failures.push(`MISSING_RELEASE_NOTE_SECTION ${section}`);
    }
    if (!/host readiness|documented-untested|pending/i.test(currentNotes)) failures.push('RELEASE_NOTE_READINESS_OVERCLAIM missing honest host-readiness vocabulary');
  }

  for (const relativePath of walk(root)) {
    if (/^RELEASE_NOTES-v.+\.md$/.test(relativePath)) {
      failures.push(`VERSIONED_RELEASE_NOTE_PRESENT ${relativePath}`);
    }
    let contents;
    try { contents = fs.readFileSync(path.join(root, relativePath), 'utf8'); } catch { continue; }
    contents.split('\n').forEach((line, index) => {
      if (!/(?:^|\/)(?:test|tests|docs\/history)\//.test(relativePath)
        && /\bcurrent\b/i.test(line) && /\b(?:release|version)\b/i.test(line)) {
        const versions = line.match(/1\.\d+\.\d+/g) || [];
        if (versions.some(version => version !== RELEASE_VERSION)) {
          failures.push(`CURRENT_VERSION_DRIFT_TEXT ${relativePath}:${index + 1}`);
          return;
        }
      }
      if (!PREVIOUS_VERSIONS.some(previous => line.includes(previous))) return;
      const classification = previousVersionClassification(relativePath, line);
      if (classification === 'current-version-drift') failures.push(`CURRENT_VERSION_DRIFT_TEXT ${relativePath}:${index + 1}`);
      else if (classification) classifications.push({ path: relativePath, line: index + 1, classification });
      else failures.push(`UNCLASSIFIED_PREVIOUS_VERSION ${relativePath}:${index + 1}`);
    });
  }
  return { product: 'LazyKimi', release_version: RELEASE_VERSION, status: failures.length ? 'fail' : 'pass', failures, classifications };
}

if (require.main === module) {
  const report = classify(path.resolve(process.argv[2] || path.join(__dirname, '..', '..')));
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
  process.exitCode = report.status === 'pass' ? 0 : 1;
}

module.exports = { classify };
