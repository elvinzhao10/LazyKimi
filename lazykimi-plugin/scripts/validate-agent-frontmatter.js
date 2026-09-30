'use strict';

// validate-agent-frontmatter.js — Kimi agent-definition policy validator.
//
// Validates plugins/lazykimi/agents/*.md against the Kimi Code CLI subagent
// schema: name, description (dispatcher style), model (kimi-k3), effort
// (low|high|max — Kimi effort scale observed on-host 2026-09-30: kimi-k3
// support_efforts = ["low","high","max"], default_effort = "high"),
// maxTurns, disallowed (denylist within Kimi's file-mutation tool universe),
// and isolation. Legacy ZCode-family keys (color, thoughtLevel, tools,
// disallowedTools, skills, memory) are rejected: Kimi uses a `disallowed`
// denylist rather than a `tools` allowlist; the intended allowlist is stated
// in each agent's body prose.

const fs = require('node:fs');
const path = require('node:path');

const EXPECTED_NAMES = new Set([
  'context-indexer', 'context-miner', 'explorer', 'gate-reviewer',
  'implementer', 'librarian', 'migration-planner', 'orchestrator',
  'planner', 'qa-executor', 'reviewer', 'security-auditor',
  'verifier',
]);
const REQUIRED_FIELDS = new Set(['name', 'description', 'model', 'effort', 'maxTurns', 'disallowed', 'isolation']);
const ALLOWED_FIELDS = new Set(REQUIRED_FIELDS);
const FORBIDDEN_FIELDS = new Set(['color', 'thoughtLevel', 'tools', 'disallowedTools', 'skills', 'memory', 'user-invocable']);
const EFFORTS = new Set(['low', 'high', 'max']);
const KIMI_TOOLS = new Set(['Read', 'Edit', 'Write', 'Bash']);
const READONLY_NAMES = new Set([
  'context-indexer', 'context-miner', 'explorer', 'gate-reviewer', 'librarian',
  'planner', 'reviewer', 'security-auditor',
]);

class AgentPolicyError extends Error {
  constructor(message) {
    super(message);
    this.name = 'AgentPolicyError';
  }
}

function refuse(message) {
  throw new AgentPolicyError(message);
}

function parseScalar(raw, filename, lineNumber) {
  const value = raw.trim();
  if (!value) refuse(`${filename}:${lineNumber}: scalar value is required`);
  if (value === '[]') return [];
  if (value === 'true') return true;
  if (value === 'false') return false;
  if (/^-?\d+$/.test(value)) return Number(value);
  if (value.startsWith('[') && value.endsWith(']')) {
    return value.slice(1, -1).length === 0 ? [] : value.slice(1, -1).split(',').map((item) => item.trim());
  }
  if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) return value.slice(1, -1);
  if (value.startsWith('"') || value.startsWith("'")) refuse(`${filename}:${lineNumber}: unterminated quoted scalar`);
  return value;
}

function parseFrontmatter(text, filename) {
  if (!text.startsWith('---\n')) refuse(`${filename}: frontmatter must start with ---`);
  const closing = text.indexOf('\n---\n', 4);
  if (closing < 0) refuse(`${filename}: frontmatter closing delimiter is missing`);
  const data = {};
  let activeList = null;
  for (const [offset, line] of text.slice(4, closing).split('\n').entries()) {
    const lineNumber = offset + 2;
    if (!line) continue;
    if (line.startsWith('  - ')) {
      if (!activeList) refuse(`${filename}:${lineNumber}: list item without a list field`);
      const item = line.slice(4).trim();
      if (!item) refuse(`${filename}:${lineNumber}: list item is empty`);
      data[activeList].push(item);
      continue;
    }
    const match = /^([A-Za-z][A-Za-z0-9]*):(.*)$/.exec(line);
    if (!match) refuse(`${filename}:${lineNumber}: unsupported YAML syntax`);
    const [, key, rawValue] = match;
    if (Object.hasOwn(data, key)) refuse(`${filename}:${lineNumber}: duplicate field ${key}`);
    if (rawValue.trim()) {
      data[key] = parseScalar(rawValue, filename, lineNumber);
      activeList = null;
    } else {
      data[key] = [];
      activeList = key;
    }
  }
  return { body: text.slice(closing + 5), data };
}

function requireString(value, field, filename, accepted) {
  if (typeof value !== 'string' || !value) refuse(`${filename}: ${field} must be a non-empty string`);
  if (accepted && !accepted.has(value)) refuse(`${filename}: unsupported ${field} ${value}`);
}

function requireList(value, field, filename, allowEmpty = false) {
  if (!Array.isArray(value) || (!allowEmpty && !value.length) || value.some((item) => typeof item !== 'string' || !item)) {
    refuse(`${filename}: ${field} must be a${allowEmpty ? '' : ' non-empty'} string list`);
  }
  if (new Set(value).size !== value.length) refuse(`${filename}: ${field} must not contain duplicates`);
}

function validateAgent(filePath) {
  const filename = path.basename(filePath);
  const entry = fs.lstatSync(filePath);
  if (!entry.isFile() || entry.isSymbolicLink()) refuse(`${filename}: agent definition must be a regular file`);
  const { body, data } = parseFrontmatter(fs.readFileSync(filePath, 'utf8'), filename);
  for (const key of Object.keys(data)) {
    if (FORBIDDEN_FIELDS.has(key)) refuse(`${filename}: legacy frontmatter field ${key} is not a Kimi agent key`);
    if (!ALLOWED_FIELDS.has(key)) refuse(`${filename}: unsupported frontmatter field ${key}`);
  }
  for (const field of REQUIRED_FIELDS) if (!Object.hasOwn(data, field)) refuse(`${filename}: required field ${field} is missing`);
  requireString(data.name, 'name', filename);
  requireString(data.description, 'description', filename);
  requireString(data.model, 'model', filename, new Set(['kimi-k3']));
  requireString(data.effort, 'effort', filename, EFFORTS);
  if (!Number.isSafeInteger(data.maxTurns) || data.maxTurns < 1 || data.maxTurns > 200) {
    refuse(`${filename}: maxTurns must be an integer between 1 and 200`);
  }
  requireList(data.disallowed, 'disallowed', filename, true);
  for (const tool of data.disallowed) {
    if (!KIMI_TOOLS.has(tool)) refuse(`${filename}: disallowed entry ${tool} is not a Kimi file-mutation tool`);
  }
  if (data.isolation !== true) refuse(`${filename}: isolation must be true (self-contained dispatches)`);
  if (data.name !== filename.replace(/^lazykimi-/, '').slice(0, -3)) refuse(`${filename}: name must match filename`);
  if (!EXPECTED_NAMES.has(data.name)) refuse(`${filename}: unexpected agent name ${data.name}`);
  const [descriptionHead] = data.description.split(/do not use/i);
  if (!/\buse (when|for|as|after)\b/i.test(descriptionHead) || !/do not use/i.test(data.description)) {
    refuse(`${filename}: description must be dispatcher style ("Use when ...; do not use for ...")`);
  }
  if (READONLY_NAMES.has(data.name)) {
    if (!data.disallowed.includes('Write') || !data.disallowed.includes('Edit')) {
      refuse(`${filename}: read-only role must disallow Write and Edit`);
    }
  }
  if (data.name === 'verifier') {
    if (data.disallowed.includes('Write') || !data.disallowed.includes('Edit')) {
      refuse(`${filename}: verifier must keep Write for its run-scoped report but disallow Edit`);
    }
  }
  if (data.name === 'implementer') {
    if (data.disallowed.length !== 0) refuse(`${filename}: implementer must retain Read, Edit, Write, and Bash`);
    if (!body.includes('DoneClaim')) refuse(`${filename}: implementer body must document its DoneClaim return`);
  }
  if (data.name === 'orchestrator') {
    if (data.disallowed.length !== 0) refuse(`${filename}: orchestrator must keep its .lazykimi/ state-write surface`);
    if (!body.includes('Subagents return a DoneClaim') || !body.includes('isolated worktree') || !body.includes('merge')) {
      refuse(`${filename}: orchestrator worktree role requires an explicit return and merge path`);
    }
  }
  return { ...data, file: filename };
}

function validateAgentDirectory(agentsDir) {
  const directory = path.resolve(agentsDir);
  const entry = fs.lstatSync(directory);
  if (!entry.isDirectory() || entry.isSymbolicLink()) refuse('agents directory must be a real directory');
  const files = fs.readdirSync(directory).filter((name) => name.endsWith('.md')).sort();
  if (files.length !== EXPECTED_NAMES.size) refuse(`agents directory must contain ${EXPECTED_NAMES.size} Markdown files`);
  const agents = files.map((file) => validateAgent(path.join(directory, file)));
  const names = new Set(agents.map((agent) => agent.name));
  if (names.size !== agents.length) refuse('agent names must be unique');
  for (const expectedName of EXPECTED_NAMES) if (!names.has(expectedName)) refuse(`agents directory is missing ${expectedName}`);
  return { agents };
}

function main(argv) {
  const args = argv.slice(2);
  const agentsDir = args.length === 0 ? path.join(__dirname, '..', 'agents') : args.length === 2 && args[0] === '--agents-dir' ? args[1] : null;
  if (!agentsDir) {
    process.stderr.write('usage: validate-agent-frontmatter.js [--agents-dir <directory>]\n');
    return 2;
  }
  try {
    const report = validateAgentDirectory(agentsDir);
    process.stdout.write(`${JSON.stringify({ ok: true, agents: report.agents })}\n`);
    return 0;
  } catch (error) {
    process.stderr.write(`${JSON.stringify({ ok: false, error: { code: 'AGENT_POLICY_INVALID', message: error.message } })}\n`);
    return 1;
  }
}

if (require.main === module) process.exitCode = main(process.argv);

module.exports = { AgentPolicyError, parseFrontmatter, validateAgentDirectory };
