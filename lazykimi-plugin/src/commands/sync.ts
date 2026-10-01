import { existsSync, readdirSync, mkdirSync, copyFileSync, chmodSync } from 'fs';
import path from 'path';
import {
  getPluginKimiCodeDir,
  getPluginAgentsDir,
  getPluginHooksDir,
  getPluginCommandsDir,
  getPluginContractsDir,
  getPluginToolingDir,
  getPluginRulesDir,
  getPluginRoot,
} from '../lib/paths';
import { rewriteMcpPaths } from './init';
import { readReceipt, sha256OfFile, writeReceipt, safeProjectPath } from '../lib/receipt';

const PLUGIN_VERSION = '1.3.4';

interface SyncOptions {
  readonly dryRun: boolean;
  readonly target: string;
}

function printHelp(): void {
  console.log(`Usage: lazykimi sync [options]

Update an existing LazyKimi installation with the current plugin templates.
Copies missing files and updates unchanged receipt-owned files.
Unknown and modified files are preserved. Runtime state under .lazykimi/state/ is never modified.

Options:
  --help, -h        Show this help message
  --dry-run         Preview actions without writing any files
  --target <path>   Target directory (default: current directory)`);
}

function parseArgs(args: string[]): SyncOptions {
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

function syncFile(
  srcPath: string,
  destPath: string,
  target: string,
  dryRun: boolean,
  actions: string[],
  synced: string[],
  receiptHashes: ReadonlyMap<string, string>,
): void {
  const rel = path.relative(target, destPath);
  if (rel === '.kimi-code/mcp.json') return;
  if (!safeProjectPath(target, rel)) { actions.push(`skip ${rel} (linked)`); return; }
  if (!existsSync(destPath)) {
    if (!dryRun) {
      mkdirSync(path.dirname(destPath), { recursive: true });
      copyFileSync(srcPath, destPath);
      if (srcPath.endsWith('.sh')) chmodSync(destPath, 0o755);
    }
    synced.push(rel);
    actions.push(`copy ${rel}`);
    return;
  }

  const targetHash = sha256OfFile(destPath);
  const receiptHash = receiptHashes.get(rel);
  const unchangedFromReceipt = receiptHash !== undefined && receiptHash === targetHash;

  if (unchangedFromReceipt) {
    if (sha256OfFile(srcPath) === targetHash) { actions.push(`unchanged ${rel}`); return; }
    if (!dryRun) {
      copyFileSync(srcPath, destPath);
      if (srcPath.endsWith('.sh')) chmodSync(destPath, 0o755);
    }
    synced.push(rel);
    actions.push(`update ${rel}`);
    return;
  }

  actions.push(`skip ${rel} (user-owned)`);
}

function syncDir(
  src: string,
  destDir: string,
  target: string,
  dryRun: boolean,
  actions: string[],
  synced: string[],
  receiptHashes: ReadonlyMap<string, string>,
): void {
  if (!existsSync(src)) return;
  const entries = readdirSync(src, { withFileTypes: true });
  for (const entry of entries) {
    if (['node_modules', '__pycache__', '.git'].includes(entry.name) || /\.py[co]$/.test(entry.name)) continue;
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(destDir, entry.name);
    if (entry.isDirectory()) {
      syncDir(srcPath, destPath, target, dryRun, actions, synced, receiptHashes);
    } else if (entry.isFile()) {
      syncFile(srcPath, destPath, target, dryRun, actions, synced, receiptHashes);
    }
  }
}

export function run(args: string[]): number {
  const opts = parseArgs(args);
  const target = path.resolve(opts.target);
  const actions: string[] = [];
  const synced: string[] = [];

  console.log(`LazyKimi sync v${PLUGIN_VERSION}`);
  console.log(`Target: ${target}`);
  if (opts.dryRun) console.log('(dry-run: no files will be written)\n');

  const receipt = readReceipt(target);
  if (!receipt) {
    console.error('No LazyKimi receipt found. Run `lazykimi init` first.');
    return 1;
  }
  const receiptHashes = new Map(receipt.files.map(f => [f.path, f.sha256]));

  // Sync .kimi-code/ templates.
  syncDir(getPluginKimiCodeDir(), path.join(target, '.kimi-code'), target, opts.dryRun, actions, synced, receiptHashes);
  syncDir(getPluginRulesDir(), path.join(target, '.kimi-code', 'rules'), target, opts.dryRun, actions, synced, receiptHashes);
  syncDir(getPluginAgentsDir(), path.join(target, '.kimi-code', 'agents'), target, opts.dryRun, actions, synced, receiptHashes);
  syncDir(getPluginHooksDir(), path.join(target, '.kimi-code', 'hooks'), target, opts.dryRun, actions, synced, receiptHashes);
  syncDir(getPluginCommandsDir(), path.join(target, '.kimi-code', 'commands'), target, opts.dryRun, actions, synced, receiptHashes);
  syncDir(getPluginContractsDir(), path.join(target, '.kimi-code', 'contracts'), target, opts.dryRun, actions, synced, receiptHashes);
  syncDir(getPluginToolingDir(), path.join(target, '.kimi-code', 'tooling'), target, opts.dryRun, actions, synced, receiptHashes);
  syncFile(
    path.join(getPluginRoot(), 'kimi.plugin.json'),
    path.join(target, '.kimi-code', 'kimi.plugin.json'),
    target,
    opts.dryRun,
    actions,
    synced,
    receiptHashes,
  );

  const ownedMcp = rewriteMcpPaths(target, opts.dryRun, actions, null);

  // Sync .lazykimi/ templates only (schemas). Never touch runtime state.
  syncDir(
    path.join(getPluginRoot(), '.lazykimi', 'schemas'),
    path.join(target, '.lazykimi', 'schemas'),
    target,
    opts.dryRun,
    actions,
    synced,
    receiptHashes,
  );

  // Update receipt: keep all existing entries that still exist, add/update synced files.
  const receiptFiles = new Set(receipt.files.filter(f => f.path !== '.kimi-code/mcp.json').map(f => f.path));
  for (const rel of Array.from(receiptFiles)) {
    if (!safeProjectPath(target, rel) || !existsSync(path.join(target, rel)) || (!synced.includes(rel) && receiptHashes.get(rel) !== sha256OfFile(path.join(target, rel)))) receiptFiles.delete(rel);
  }
  for (const rel of synced) receiptFiles.add(rel);

  if (!opts.dryRun) {
    writeReceipt(target, Array.from(receiptFiles), PLUGIN_VERSION, ownedMcp);
    actions.push('write .kimi-code/.lazykimi-receipt.json');
  }

  console.log('\n=== Actions ===');
  for (const a of actions) console.log(`  ${opts.dryRun ? '[dry-run] ' : ''}${a}`);
  console.log(`\n${opts.dryRun ? 'Preview complete' : 'Sync complete'}. ${synced.length} file(s) ${opts.dryRun ? 'would be ' : ''}updated.`);
  return 0;
}
