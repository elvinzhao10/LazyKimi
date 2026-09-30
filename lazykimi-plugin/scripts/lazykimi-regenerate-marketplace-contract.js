#!/usr/bin/env node
'use strict';

// Regenerates contracts/marketplace-route-contract.v1.json payload inventory and
// artifact digests after any payload edit, then refreshes the .sha256 sidecar.
// Run after ANY edit under .kimi-code/skills/, commands/, agents/, hooks/, mcp/,
// .kimi-code/mcp.json, or kimi.plugin.json. Counts are derived from the
// canonical trees (metadata-drift rule: no hand-maintained duplicates).
// Usage: node scripts/lazykimi-regenerate-marketplace-contract.js [releaseRoot]

const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const releaseRoot = process.argv[2] === undefined
  ? path.resolve(__dirname, '..', '..')
  : path.resolve(process.argv[2]);
const pluginRoot = path.join(releaseRoot, 'lazykimi-plugin');
const contractPath = path.join(pluginRoot, 'contracts', 'marketplace-route-contract.v1.json');

const digest = (bytes) => crypto.createHash('sha256').update(bytes).digest('hex');

const contract = JSON.parse(fs.readFileSync(contractPath, 'utf8'));

// Artifacts: byte digests of the marketplace catalog and plugin manifest.
for (const relative of Object.keys(contract.artifacts)) {
  contract.artifacts[relative] = digest(fs.readFileSync(path.join(releaseRoot, relative)));
}

// Payload inventory: same algorithm as lifecycle/marketplace-routes.js inventory().
const records = [];
const walk = (relative) => {
  const directory = path.join(pluginRoot, relative);
  for (const name of fs.readdirSync(directory).sort((l, r) => Buffer.compare(Buffer.from(l), Buffer.from(r)))) {
    const child = path.posix.join(relative, name);
    const absolute = path.join(pluginRoot, child);
    const stat = fs.lstatSync(absolute);
    if (stat.isDirectory() && !stat.isSymbolicLink()) walk(child);
    else if (stat.isFile() && stat.nlink === 1 && name !== '.gitkeep') {
      records.push({ path: child, sha256: digest(fs.readFileSync(absolute)) });
    } else if (name !== '.gitkeep') {
      throw new Error(`canonical payload must contain only regular files: ${child}`);
    }
  }
};
for (const root of contract.payload.roots) walk(root);
for (const relative of contract.payload.files) {
  records.push({ path: relative, sha256: digest(fs.readFileSync(path.join(pluginRoot, relative))) });
}
records.sort((l, r) => Buffer.compare(Buffer.from(l.path), Buffer.from(r.path)));
contract.payload.file_count = records.length;
contract.payload.inventory_sha256 = digest(Buffer.from(JSON.stringify(records)));

// Derived counts from the canonical trees (never hand-maintained).
const skillRoot = path.join(pluginRoot, '.kimi-code', 'skills');
contract.payload.counts.skills = fs.readdirSync(skillRoot, { withFileTypes: true })
  .filter((entry) => entry.isDirectory()).length;
const countFiles = (relative, filter) => fs.readdirSync(path.join(pluginRoot, relative))
  .filter((name) => !name.startsWith('.') && filter(name)).length;
contract.payload.counts.commands = countFiles('commands', (n) => n.endsWith('.md'));
contract.payload.counts.agents = countFiles('agents', (n) => n.endsWith('.md'));
contract.payload.counts.hook_events = countFiles('hooks', (n) => n.endsWith('.sh'));
// Declared MCP servers come from the canonical manifest declaration. mcp/ may
// also ship optional env-gated wrappers (codegraph) that are NOT declared
// servers and stay out of both registration surfaces — counting directories
// would over-report them, so count kimi.plugin.json mcpServers instead.
const manifest = JSON.parse(fs.readFileSync(path.join(pluginRoot, 'kimi.plugin.json'), 'utf8'));
contract.payload.counts.mcp_servers = Object.keys(manifest.mcpServers || {}).length;

const serialized = `${JSON.stringify(contract, null, 2)}\n`;
fs.writeFileSync(contractPath, serialized);
fs.writeFileSync(`${contractPath}.sha256`, `${digest(Buffer.from(serialized))}  marketplace-route-contract.v1.json\n`);

process.stdout.write(`${JSON.stringify({ status: 'regenerated', file_count: contract.payload.file_count, counts: contract.payload.counts, inventory_sha256: contract.payload.inventory_sha256 })}\n`);
