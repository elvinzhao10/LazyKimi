import { existsSync, readdirSync } from 'fs';
import path from 'path';
import { spawnSync } from 'child_process';
import { readJson, isObject } from '../lib/json';

const PLUGIN_VERSION = '0.1.0';
const EXPECTED_SKILLS = 17;
const EXPECTED_AGENTS = 11;
const EXPECTED_HOOKS = 16;
const EXPECTED_MCP = 6;

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

function countSkills(kimiCodeDir: string): number {
  const skillsDir = path.join(kimiCodeDir, 'skills');
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

function countAgents(kimiCodeDir: string): number {
  const agentsDir = path.join(kimiCodeDir, 'agents');
  if (!existsSync(agentsDir)) return 0;
  return readdirSync(agentsDir).filter(f => f.startsWith('lazykimi-') && f.endsWith('.md')).length;
}

function countHooks(kimiCodeDir: string): number {
  const hooksDir = path.join(kimiCodeDir, 'hooks');
  if (!existsSync(hooksDir)) return 0;
  return readdirSync(hooksDir).filter(f => f.endsWith('.sh')).length;
}

function countMcpServers(kimiCodeDir: string): number {
  const mcpPath = path.join(kimiCodeDir, 'mcp.json');
  if (!existsSync(mcpPath)) return -1;
  try {
    const data = readJson(mcpPath);
    if (!isObject(data)) return -1;
    const servers = data.mcpServers;
    if (!isObject(servers)) return -1;
    return Object.keys(servers).length;
  } catch {
    return -1;
  }
}

function checkBoulderState(target: string): CheckResult {
  const boulderPath = path.join(target, '.lazykimi', 'state', 'boulder.json');
  if (!existsSync(boulderPath)) {
    return { label: '.lazykimi/state/boulder.json', status: 'FAIL', detail: 'not found' };
  }
  try {
    const data = readJson(boulderPath);
    if (!isObject(data)) {
      return { label: '.lazykimi/state/boulder.json', status: 'FAIL', detail: 'not a JSON object' };
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
  const kimiCodeDir = path.join(target, '.kimi-code');

  checks.push({
    label: '.kimi-code/ present',
    status: existsSync(kimiCodeDir) ? 'PASS' : 'FAIL',
    detail: existsSync(kimiCodeDir) ? undefined : 'run `lazykimi init` first',
  });

  const skillCount = countSkills(kimiCodeDir);
  checks.push({
    label: `skills count (${EXPECTED_SKILLS} expected)`,
    status: skillCount === EXPECTED_SKILLS ? 'PASS' : 'FAIL',
    detail: `found ${skillCount}`,
  });

  const agentCount = countAgents(kimiCodeDir);
  checks.push({
    label: `agents count (${EXPECTED_AGENTS} expected)`,
    status: agentCount === EXPECTED_AGENTS ? 'PASS' : 'FAIL',
    detail: `found ${agentCount}`,
  });

  const hookCount = countHooks(kimiCodeDir);
  checks.push({
    label: `hooks count (${EXPECTED_HOOKS} expected)`,
    status: hookCount === EXPECTED_HOOKS ? 'PASS' : 'FAIL',
    detail: `found ${hookCount}`,
  });

  const mcpCount = countMcpServers(kimiCodeDir);
  checks.push({
    label: `mcp.json valid (${EXPECTED_MCP} servers)`,
    status: mcpCount === EXPECTED_MCP ? 'PASS' : 'FAIL',
    detail: mcpCount < 0 ? 'invalid or missing' : `found ${mcpCount} servers`,
  });

  checks.push(checkBoulderState(target));
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
