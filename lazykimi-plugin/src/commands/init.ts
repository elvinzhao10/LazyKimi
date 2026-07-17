import { existsSync, readdirSync, mkdirSync, copyFileSync, chmodSync } from 'fs';
import path from 'path';
import { getPluginKimiCodeDir, getPluginAgentsDir, getPluginHooksDir, getKimiConfigFile } from '../lib/paths';
import { writeJson } from '../lib/json';
import { appendHooksToConfig, isHooksInstalled } from '../lib/hooks-config';
import { writeReceipt } from '../lib/receipt';

const PLUGIN_VERSION = '0.1.0';
const EXPECTED_SKILLS = 17;
const EXPECTED_AGENTS = 11;
const EXPECTED_HOOKS = 8;
const EXPECTED_MCP = 6;

interface InitOptions {
  readonly dryRun: boolean;
  readonly target: string;
}

function printHelp(): void {
  console.log(`Usage: lazykimi init [options]

Install LazyKimi into a target project. Copies .kimi-code/ (skills, agents,
AGENTS.md, mcp.json, hooks) and .lazykimi/ seed state, then appends hooks to
~/.kimi-code/config.toml idempotently.

Options:
  --help, -h        Show this help message
  --dry-run         Preview actions without writing any files
  --target <path>   Target directory (default: current directory)`);
}

function parseArgs(args: string[]): InitOptions {
  let dryRun = false;
  let target = process.cwd();
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === '--help' || a === '-h') { printHelp(); process.exit(0); }
    else if (a === '--dry-run') dryRun = true;
    else if (a === '--target' && i + 1 < args.length) target = args[++i];
  }
  return { dryRun, target };
}

function copyDir(
  src: string,
  destDir: string,
  target: string,
  dryRun: boolean,
  actions: string[],
  copied: string[],
): void {
  if (!existsSync(src)) return;
  const entries = readdirSync(src, { withFileTypes: true });
  for (const entry of entries) {
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(destDir, entry.name);
    if (entry.isDirectory()) {
      copyDir(srcPath, destPath, target, dryRun, actions, copied);
    } else if (entry.isFile()) {
      if (!dryRun) {
        mkdirSync(path.dirname(destPath), { recursive: true });
        copyFileSync(srcPath, destPath);
        if (entry.name.endsWith('.sh')) chmodSync(destPath, 0o755);
      }
      const rel = path.relative(target, destPath);
      copied.push(rel);
      actions.push(`copy ${rel}`);
    }
  }
}

function ensureDir(dir: string, dryRun: boolean, actions: string[], rel: string): void {
  if (!dryRun) mkdirSync(dir, { recursive: true });
  actions.push(`mkdir ${rel}`);
}

function writeSeedJson(rel: string, data: unknown, target: string, dryRun: boolean, actions: string[]): void {
  if (!dryRun) writeJson(path.join(target, rel), data);
  actions.push(`write ${rel}`);
}

function defaultBoulderState(): unknown {
  return { schema_version: 1, active_goal_id: null, tasks: [], blockers: [] };
}

function defaultConfig(): unknown {
  return { host: 'kimi-code-cli', model: 'kimi-k3', state_dir: '.lazykimi' };
}

export function run(args: string[]): number {
  const opts = parseArgs(args);
  const target = path.resolve(opts.target);
  const actions: string[] = [];
  const copied: string[] = [];

  console.log(`LazyKimi init v${PLUGIN_VERSION}`);
  console.log(`Target: ${target}`);
  if (opts.dryRun) console.log('(dry-run: no files will be written)\n');

  // 1. Copy .kimi-code/ template (skills/, AGENTS.md, mcp.json)
  copyDir(getPluginKimiCodeDir(), path.join(target, '.kimi-code'), target, opts.dryRun, actions, copied);
  // 2. Copy agents/ -> .kimi-code/agents/
  copyDir(getPluginAgentsDir(), path.join(target, '.kimi-code', 'agents'), target, opts.dryRun, actions, copied);
  // 3. Copy hooks/ -> .kimi-code/hooks/
  copyDir(getPluginHooksDir(), path.join(target, '.kimi-code', 'hooks'), target, opts.dryRun, actions, copied);

  // 4. Create .lazykimi/ seed state
  ensureDir(path.join(target, '.lazykimi', 'state'), opts.dryRun, actions, '.lazykimi/state');
  ensureDir(path.join(target, '.lazykimi', 'evidence'), opts.dryRun, actions, '.lazykimi/evidence');
  ensureDir(path.join(target, '.lazykimi', 'schemas'), opts.dryRun, actions, '.lazykimi/schemas');
  ensureDir(path.join(target, '.lazykimi', 'plans'), opts.dryRun, actions, '.lazykimi/plans');
  ensureDir(path.join(target, '.lazykimi', 'loop'), opts.dryRun, actions, '.lazykimi/loop');
  writeSeedJson('.lazykimi/state/boulder.json', defaultBoulderState(), target, opts.dryRun, actions);
  writeSeedJson('.lazykimi/config.json', defaultConfig(), target, opts.dryRun, actions);

  // 5. Append hooks to ~/.kimi-code/config.toml (idempotent)
  const configFile = getKimiConfigFile();
  if (opts.dryRun) {
    const installed = isHooksInstalled(configFile);
    actions.push(installed ? `skip hooks (already present)` : `append hooks to ${configFile}`);
  } else {
    try {
      const result = appendHooksToConfig(configFile);
      actions.push(result.changed ? `append hooks to ${configFile}` : `skip hooks (${result.reason})`);
    } catch (e) {
      actions.push(`FAIL hooks: ${e instanceof Error ? e.message : String(e)}`);
    }
  }

  // 6. Write receipt tracking installed .kimi-code/ files
  if (!opts.dryRun) {
    writeReceipt(target, copied, PLUGIN_VERSION);
    actions.push('write .kimi-code/.lazykimi-receipt.json');
  }

  // Report
  console.log('\n=== Actions ===');
  for (const a of actions) console.log(`  ${opts.dryRun ? '[dry-run] ' : ''}${a}`);
  console.log(`\n${opts.dryRun ? 'Preview complete' : 'Install complete'}. ${copied.length} file(s) ${opts.dryRun ? 'would be ' : ''}copied.`);
  console.log(`Expected: ${EXPECTED_SKILLS} skills, ${EXPECTED_AGENTS} agents, ${EXPECTED_HOOKS} hooks, ${EXPECTED_MCP} MCP servers.`);
  console.log('Run `lazykimi doctor` to verify, `lazykimi load-check` for package readiness.');
  return 0;
}
