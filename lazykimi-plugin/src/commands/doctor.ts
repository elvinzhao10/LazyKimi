import { existsSync, readdirSync } from 'fs';
import path from 'path';
import { spawnSync } from 'child_process';
import { readJson, isObject } from '../lib/json';
import { isPluginSourceRoot } from '../lib/paths';
import { validateMcpServers, REQUIRED_MCP_SERVERS } from '../lib/mcp-validation';

const PLUGIN_VERSION = '0.2.0';
const EXPECTED_SKILLS = 17;
const EXPECTED_AGENTS = 11;
const EXPECTED_HOOKS = 16;

export type CheckStatus = 'PASS' | 'FAIL' | 'WARN';

export interface CheckResult {
  readonly label: string;
  readonly status: CheckStatus;
  readonly detail?: string;
}

export interface DoctorResult {
  readonly checks: CheckResult[];
  readonly pass: number;
  readonly fail: number;
  readonly warn: number;
}

function countSkills(skillsRoot: string): number {
  const skillsDir = path.join(skillsRoot, 'skills');
  if (!existsSync(skillsDir)) return 0;
  const entries = readdirSync(skillsDir, { withFileTypes: true });
  let count = 0;
  for (const e of entries) {
    if (e.isDirectory() && e.name.startsWith('lazy-')) {
      if (existsSync(path.join(skillsDir, e.name, 'SKILL.md'))) count++;
    }
  }
  return count;
}

function countAgents(agentsDir: string): number {
  if (!existsSync(agentsDir)) return 0;
  return readdirSync(agentsDir).filter(f => f.startsWith('lazykimi-') && f.endsWith('.md')).length;
}

function countHooks(hooksDir: string): number {
  if (!existsSync(hooksDir)) return 0;
  return readdirSync(hooksDir).filter(f => f.endsWith('.sh')).length;
}

function checkBoulderState(boulderPath: string): CheckResult {
  if (!existsSync(boulderPath)) {
    return { label: '.lazykimi/state/boulder.json', status: 'FAIL', detail: 'not found' };
  }
  try {
    const data = readJson(boulderPath);
    if (!isObject(data)) {
      return { label: '.lazykimi/state/boulder.json', status: 'FAIL', detail: 'not a JSON object' };
    }
    if (typeof data.schema_version !== 'number') {
      return { label: '.lazykimi/state/boulder.json', status: 'FAIL', detail: 'schema_version must be a number' };
    }
    if (typeof data.active_work_id !== 'string' && data.active_work_id !== null) {
      return { label: '.lazykimi/state/boulder.json', status: 'FAIL', detail: 'active_work_id must be a string or null' };
    }
    if (!isObject(data.works)) {
      return { label: '.lazykimi/state/boulder.json', status: 'FAIL', detail: 'works must be an object' };
    }
    return { label: '.lazykimi/state/boulder.json', status: 'PASS' };
  } catch (e) {
    return {
      label: '.lazykimi/state/boulder.json',
      status: 'FAIL',
      detail: e instanceof Error ? e.message : String(e),
    };
  }
}

function checkKimiBinary(): CheckResult {
  const result = spawnSync('which', ['kimi'], { encoding: 'utf-8', stdio: 'pipe' });
  if (result.status === 0) {
    return { label: 'kimi binary on PATH', status: 'PASS', detail: result.stdout.trim() };
  }
  return {
    label: 'kimi binary on PATH',
    status: 'WARN',
    detail: 'kimi not found on PATH (install from Kimi Platform)',
  };
}

export function runDoctor(target: string): DoctorResult {
  const checks: CheckResult[] = [];
  const isPluginRoot = isPluginSourceRoot(target);

  const resolvedKimiCodeDir = path.join(target, '.kimi-code');
  const skillsRoot = isPluginRoot
    ? (existsSync(resolvedKimiCodeDir) ? resolvedKimiCodeDir : path.join(target, 'skills'))
    : resolvedKimiCodeDir;
  const agentsDir = isPluginRoot ? path.join(target, 'agents') : path.join(resolvedKimiCodeDir, 'agents');
  const hooksDir = isPluginRoot ? path.join(target, 'hooks') : path.join(resolvedKimiCodeDir, 'hooks');
  const mcpPath = path.join(resolvedKimiCodeDir, 'mcp.json');
  const resolvedBoulderPath = isPluginRoot
    ? (
        existsSync(path.join(target, '.lazykimi', 'state', 'boulder.json'))
          ? path.join(target, '.lazykimi', 'state', 'boulder.json')
          : path.join(target, '..', '.lazykimi', 'state', 'boulder.json')
      )
    : path.join(target, '.lazykimi', 'state', 'boulder.json');

  checks.push({
    label: '.kimi-code/ present',
    status: existsSync(path.join(target, '.kimi-code')) ? 'PASS' : 'FAIL',
    detail: existsSync(path.join(target, '.kimi-code')) ? undefined : 'run `lazykimi init` first',
  });

  const skillCount = countSkills(skillsRoot);
  checks.push({
    label: `skills count (${EXPECTED_SKILLS} expected)`,
    status: skillCount === EXPECTED_SKILLS ? 'PASS' : 'FAIL',
    detail: `found ${skillCount}`,
  });

  const agentCount = countAgents(agentsDir);
  checks.push({
    label: `agents count (${EXPECTED_AGENTS} expected)`,
    status: agentCount === EXPECTED_AGENTS ? 'PASS' : 'FAIL',
    detail: `found ${agentCount}`,
  });

  const hookCount = countHooks(hooksDir);
  checks.push({
    label: `hooks count (${EXPECTED_HOOKS} expected)`,
    status: hookCount === EXPECTED_HOOKS ? 'PASS' : 'FAIL',
    detail: `found ${hookCount}`,
  });

  const mcpValidation = validateMcpServers(mcpPath);
  const mcpDetailParts: string[] = [
    `found ${mcpValidation.count} servers (${mcpValidation.required} required, ${mcpValidation.optional} optional)`,
  ];
  if (mcpValidation.missing.length > 0) {
    mcpDetailParts.push(`missing ${mcpValidation.missing.join(', ')}`);
  }
  if (mcpValidation.unknown.length > 0) {
    mcpDetailParts.push(`unknown ${mcpValidation.unknown.join(', ')}`);
  }
  checks.push({
    label: `mcp.json valid (${REQUIRED_MCP_SERVERS.length} required servers)`,
    status: mcpValidation.valid ? 'PASS' : 'FAIL',
    detail: mcpDetailParts.join('; '),
  });

  checks.push(checkBoulderState(resolvedBoulderPath));
  checks.push(checkKimiBinary());

  let pass = 0, fail = 0, warn = 0;
  for (const c of checks) {
    if (c.status === 'PASS') pass++;
    else if (c.status === 'FAIL') fail++;
    else warn++;
  }
  return { checks, pass, fail, warn };
}

export function run(args: string[]): number {
  if (args.includes('--help') || args.includes('-h')) {
    console.log(`Usage: lazykimi doctor

Check LazyKimi installation health in the current directory.

Options:
  --help, -h   Show this help message`);
    return 0;
  }
  const target = process.cwd();
  const result = runDoctor(target);
  console.log(`LazyKimi Doctor v${PLUGIN_VERSION}`);
  console.log(`Target: ${target}\n`);
  const maxLabel = Math.max(...result.checks.map(c => c.label.length));
  for (const c of result.checks) {
    const label = c.label.padEnd(maxLabel + 2);
    console.log(`  [${c.status}] ${label} ${c.detail ?? ''}`);
  }
  console.log(`\n=== Results: ${result.pass} PASS, ${result.warn} WARN, ${result.fail} FAIL ===`);
  return result.fail > 0 ? 1 : 0;
}
