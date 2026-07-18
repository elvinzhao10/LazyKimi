import { existsSync, readdirSync, mkdirSync, copyFileSync, chmodSync, readFileSync, writeFileSync } from 'fs';
import path from 'path';
import { getPluginKimiCodeDir, getPluginAgentsDir, getPluginHooksDir, getPluginRoot } from '../lib/paths';
import { writeJson } from '../lib/json';
import { writeReceipt } from '../lib/receipt';

const PLUGIN_VERSION = '0.2.0';
const EXPECTED_SKILLS = 17;
const EXPECTED_AGENTS = 11;
const EXPECTED_HOOKS = 16;
const EXPECTED_MCP = 6;

interface InitOptions {
  readonly dryRun: boolean;
  readonly target: string;
}

function printHelp(): void {
  console.log(`Usage: lazykimi init [options]

Install LazyKimi into a target project. Copies .kimi-code/ (skills, agents,
AGENTS.md, mcp.json, hooks) and .lazykimi/ seed state. Hook scripts are
copied to <target>/.kimi-code/hooks/ but NOT auto-appended to
~/.kimi-code/config.toml — see the post-install message for activation.

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

function writeEvidenceTemplates(target: string, dryRun: boolean, actions: string[]): void {
  const files: ReadonlyArray<readonly [string, string]> = [
    ['plan-reread.md', '# Plan Reread Evidence\n\n(none yet)\n'],
    ['test-runs.md', '# Test Runs Evidence\n\n(none yet)\n'],
    ['manual-qa.md', '# Manual QA Evidence\n\n(none yet)\n'],
    ['oracle-review.md', '# Oracle Review Evidence\n\n(none yet)\n'],
    ['reviewer.md', '# Reviewer Evidence\n\n(none yet)\n'],
  ];
  for (const [name, content] of files) {
    const rel = path.join('.lazykimi', 'evidence', name);
    if (!dryRun) writeFileSync(path.join(target, rel), content, 'utf-8');
    actions.push(`write ${rel}`);
  }
}

function rewriteMcpPaths(target: string, dryRun: boolean, actions: string[]): void {
  // Kimi Code CLI does not interpolate env vars in .kimi-code/mcp.json (per
  // https://www.kimi.com/code/docs/kimi-code-cli/customization/mcp.html). The
  // source template ships with __KIMI_PLUGIN_ROOT__ placeholders that we
  // rewrite to absolute paths at install time so the project-level mcp.json
  // resolves server.sh correctly regardless of CWD.
  const mcpPath = path.join(target, '.kimi-code', 'mcp.json');
  if (!existsSync(mcpPath)) return;
  const pluginRoot = getPluginRoot();
  if (dryRun) {
    actions.push(`rewrite mcp.json paths (__KIMI_PLUGIN_ROOT__ -> ${pluginRoot})`);
    return;
  }
  const raw = readFileSync(mcpPath, 'utf-8');
  const rewritten = raw.replace(/__KIMI_PLUGIN_ROOT__/g, pluginRoot);
  writeFileSync(mcpPath, rewritten, 'utf-8');
  actions.push(`rewrite mcp.json paths (absolute: ${pluginRoot})`);
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
  // 1b. Rewrite __KIMI_PLUGIN_ROOT__ placeholders in the copied mcp.json to
  //     absolute plugin-root paths (Kimi does not interpolate env vars in
  //     project-level mcp.json).
  rewriteMcpPaths(target, opts.dryRun, actions);
  // 2. Copy agents/ -> .kimi-code/agents/
  copyDir(getPluginAgentsDir(), path.join(target, '.kimi-code', 'agents'), target, opts.dryRun, actions, copied);
  // 3. Copy hooks/ -> .kimi-code/hooks/
  copyDir(getPluginHooksDir(), path.join(target, '.kimi-code', 'hooks'), target, opts.dryRun, actions, copied);

  // 4. Create .lazykimi/ seed state
  ensureDir(path.join(target, '.lazykimi', 'state'), opts.dryRun, actions, '.lazykimi/state');
  ensureDir(path.join(target, '.lazykimi', 'evidence'), opts.dryRun, actions, '.lazykimi/evidence');
  writeEvidenceTemplates(target, opts.dryRun, actions);
  ensureDir(path.join(target, '.lazykimi', 'schemas'), opts.dryRun, actions, '.lazykimi/schemas');
  ensureDir(path.join(target, '.lazykimi', 'plans'), opts.dryRun, actions, '.lazykimi/plans');
  ensureDir(path.join(target, '.lazykimi', 'loop'), opts.dryRun, actions, '.lazykimi/loop');
  // 4b. Copy JSON Schema files from <plugin>/.lazykimi/schemas/*.schema.json
  //     into <target>/.lazykimi/schemas/ so installed projects can validate
  //     boulder, evidence, sessions, and active-loop state files.
  copyDir(
    path.join(getPluginRoot(), '.lazykimi', 'schemas'),
    path.join(target, '.lazykimi', 'schemas'),
    target,
    opts.dryRun,
    actions,
    copied,
  );
  writeSeedJson('.lazykimi/state/boulder.json', defaultBoulderState(), target, opts.dryRun, actions);
  writeSeedJson('.lazykimi/config.json', defaultConfig(), target, opts.dryRun, actions);

  // 5. Hooks: scripts are copied (step 3) but NOT auto-appended to
  //    ~/.kimi-code/config.toml. The plugin manifest (kimi.plugin.json)
  //    handles hook activation when installed via /plugins install. Users
  //    who clone the repo without /plugins install must run install-hooks.sh
  //    to wire config.toml entries with absolute paths.
  if (!opts.dryRun) {
    const pluginRoot = getPluginRoot();
    console.log('');
    console.log(`Hooks: ${EXPECTED_HOOKS} hook scripts copied to .kimi-code/hooks/`);
    console.log('To activate hooks via config.toml (alternative to /plugins install), run:');
    console.log(`  bash ${pluginRoot}/scripts/install-hooks.sh --project-root ${target}`);
    console.log(`Or install as a plugin via /plugins install ${pluginRoot} (hooks auto-activate from manifest).`);
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
