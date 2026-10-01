'use strict';

// Product-naming policy for the LazyKimi repository.
//
// Scans tracked text files for sibling-product and retired-host vocabulary
// (lazyzcode / lazytrae / lazybuddy / lazyqoder / codebuddy / zcode /
// CLAUDE_PLUGIN_ROOT / .lazyzcode / .trae) and for the retired Greek-myth
// agent names, then fails on any occurrence not covered by
// .product-naming-allowlist.json. Family-shared byte-identical contracts are
// exempt by content hash: a contract is exempt only while its bytes still
// match its tracked .sha256 sidecar (the sidecars were copied from the
// LazyZCode v1.3.4 release, so the exemption is hash-pinned, not
// path-globbed). The scripts/hooks bridge symlink is skipped for the same
// reason the family's v122 harness-semantic-parity work introduced it: it is
// a bridge to the canonical hooks directory, not a second surface.

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { execFileSync } = require('node:child_process');

const root = process.env.PRODUCT_NAMING_ROOT ? path.resolve(process.env.PRODUCT_NAMING_ROOT) : path.resolve(__dirname, '..');
const ALLOWLIST_PATH = path.join(root, '.product-naming-allowlist.json');

const SIBLING_PRODUCT_PATTERN = /\b(?:lazyzcode|lazytrae|lazybuddy|lazyqoder|codebuddy|zcode)\b/gi;
const RETIRED_HOOK_ENV_PATTERN = /CLAUDE_PLUGIN_ROOT/g;
const RETIRED_STATE_DIR_PATTERN = /\.(?:lazyzcode|trae)\b/g;
const GREEK_AGENT_PATTERN = /\b(?:sisyphus|sisypus|metis|hephaestus|oracle|momus|prometheus|atlas)\b/gi;

const CLASSIFICATIONS = new Set([
  'verbatim-eval-quote', 'attribution', 'old-release-note',
  'immutable-historical-fixture', 'source-identity', 'stable-machine-id', 'old-note',
  'family-contract-hash-exempt',
]);

function fail(message) {
  process.stderr.write(`NAMING_ERROR: ${message}\n`);
  process.exitCode = 1;
}

function parseAllowlist() {
  let raw;
  try {
    raw = fs.readFileSync(ALLOWLIST_PATH, 'utf8');
  } catch (error) {
    if (error && error.code === 'ENOENT') {
      fail(`cannot parse .product-naming-allowlist.json: ENOENT: no such file or directory, open '${ALLOWLIST_PATH}'`);
      return null;
    }
    throw error;
  }
  let value;
  try {
    value = JSON.parse(raw);
  } catch (error) {
    fail(`cannot parse .product-naming-allowlist.json: ${error.message}`);
    return null;
  }
  if (!value || !Array.isArray(value.formerDisplayNames) || !Array.isArray(value.stableIdentityFiles) || !Array.isArray(value.currentHostPages)) {
    fail('allowlist must define formerDisplayNames, stableIdentityFiles, and currentHostPages arrays');
    return null;
  }
  for (const [index, entry] of value.formerDisplayNames.entries()) {
    if (typeof entry.path !== 'string' || typeof entry.text !== 'string' || !Number.isInteger(entry.count) || entry.count < 1
      || !CLASSIFICATIONS.has(entry.classification) || typeof entry.reason !== 'string' || entry.reason === '') {
      fail(`formerDisplayNames[${index}] requires path, text, positive count, approved classification, and reason`);
      return null;
    }
  }
  for (const [index, entry] of value.stableIdentityFiles.entries()) {
    if (typeof entry.path !== 'string' || !entry.ids || typeof entry.ids !== 'object' || Array.isArray(entry.ids)
      || !Object.entries(entry.ids).every(([id, count]) => typeof id === 'string' && Number.isInteger(count) && count >= 0)) {
      fail(`stableIdentityFiles[${index}] requires path and ids object`);
      return null;
    }
  }
  if (value.currentHostPages.some(item => typeof item !== 'string' || item === '')) fail('currentHostPages entries must be non-empty paths');
  return value;
}

function walkFiles(directory, base = directory) {
  const files = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true }).sort((left, right) => left.name.localeCompare(right.name))) {
    if (entry.name === '.git' || entry.name === 'node_modules' || entry.name === 'sources' || entry.name === 'dist' || entry.name === '.study') continue;
    const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) files.push(...walkFiles(absolute, base));
    else if (entry.isFile()) files.push(path.relative(base, absolute).split(path.sep).join('/'));
    // Symlinks (the scripts/hooks bridge) are deliberately not followed.
  }
  return files;
}

function trackedFiles() {
  try {
    return execFileSync('git', ['ls-files', '-z'], { cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).split('\0').filter(Boolean);
  } catch {
    // Repository checkouts are transport-only; fall back to a filesystem walk.
    return walkFiles(root);
  }
}

function readText(relativePath) {
  const absolute = path.join(root, relativePath);
  const stat = fs.lstatSync(absolute);
  if (stat.isSymbolicLink()) return null; // bridge symlink: not a second surface
  const buffer = fs.readFileSync(absolute);
  return buffer.includes(0) ? null : buffer.toString('utf8');
}

function sha256(buffer) {
  return crypto.createHash('sha256').update(buffer).digest('hex');
}

// A contract is hash-exempt while its bytes match its tracked .sha256 sidecar.
// The sidecar set was copied verbatim from the LazyZCode v1.3.4 release, so a
// byte-identical family file stays exempt and any local edit immediately
// resurfaces naming review instead of silently riding the exemption.
function isHashExemptContract(relativePath) {
  if (!relativePath.startsWith('lazykimi-plugin/contracts/')) return false;
  const sidecarPath = path.join(root, `${relativePath}.sha256`);
  let sidecar;
  try {
    sidecar = fs.readFileSync(sidecarPath, 'utf8');
  } catch {
    return false;
  }
  const pinned = sidecar.trim().split(/\s+/)[0];
  if (!/^[0-9a-f]{64}$/.test(pinned)) return false;
  let buffer;
  try {
    buffer = fs.readFileSync(path.join(root, relativePath));
  } catch {
    return false;
  }
  return sha256(buffer) === pinned;
}

function countExact(content, text) {
  return content.split(text).length - 1;
}

const allowlist = parseAllowlist();
if (allowlist) {
  const files = trackedFiles();
  const observed = new Map();
  const patterns = [
    ['sibling-product', SIBLING_PRODUCT_PATTERN],
    ['retired-hook-env', RETIRED_HOOK_ENV_PATTERN],
    ['retired-state-dir', RETIRED_STATE_DIR_PATTERN],
    ['greek-agent', GREEK_AGENT_PATTERN],
  ];
  for (const relativePath of files) {
    if (relativePath === '.product-naming-allowlist.json' || relativePath === 'scripts/check-product-naming.js') continue;
    if (isHashExemptContract(relativePath)) continue;
    const content = readText(relativePath);
    if (content === null) continue;
    for (const [label, pattern] of patterns) {
      const scoped = new RegExp(pattern.source, pattern.flags);
      for (const match of content.matchAll(scoped)) {
        // Keys are normalized to lowercase so allowlist entries are
        // casing-stable while the scan itself stays case-insensitive.
        const key = `${relativePath}\0${match[0].toLowerCase()}`;
        observed.set(key, (observed.get(key) || 0) + 1);
        void label;
      }
    }
  }

  const allowed = new Set();
  for (const entry of allowlist.formerDisplayNames) {
    const key = `${entry.path}\0${entry.text.toLowerCase()}`;
    if (allowed.has(key)) fail(`duplicate former display-name allowlist entry: ${entry.path} :: ${entry.text}`);
    allowed.add(key);
    const actual = observed.get(key) || 0;
    if (actual !== entry.count) fail(`${entry.path} :: ${entry.text} expected ${entry.count} allowlisted occurrence(s), found ${actual}`);
  }
  for (const [key, count] of observed.entries()) {
    if (!allowed.has(key)) fail(`${key.replace('\0', ' :: ')} has ${count} unallowlisted former display-name occurrence(s)`);
  }

  for (const entry of allowlist.stableIdentityFiles) {
    let content;
    try {
      content = readText(entry.path);
    } catch {
      content = null;
    }
    if (content === null) {
      fail(`${entry.path} stable identity contract is not text`);
      continue;
    }
    for (const [id, expected] of Object.entries(entry.ids)) {
      const actual = countExact(content, id);
      if (actual !== expected) fail(`${entry.path} stable ID ${id} expected ${expected} occurrence(s), found ${actual}`);
    }
  }

  for (const relativePath of allowlist.currentHostPages) {
    let content = null;
    try {
      content = readText(relativePath);
    } catch {
      content = null;
    }
    if (content === null || !content.includes('Kimi') || !content.includes('kimi')) {
      fail(`${relativePath} must use the canonical Kimi product and executable spellings`);
    }
  }
}

if (process.exitCode) process.exit(process.exitCode);
process.stdout.write('NAMING_OK: zero unallowlisted retired names; family contracts hash-exempt; host spellings verified\n');
