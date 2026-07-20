import { existsSync, readdirSync, mkdirSync, copyFileSync, chmodSync, readFileSync, writeFileSync } from 'fs';
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
import { readReceipt, sha256OfFile, writeReceipt } from '../lib/receipt';

const PLUGIN_VERSION = '0.2.0';
const MANAGED_START = '<!-- lazykimi:managed:start -->';
const MANAGED_END = '<!-- lazykimi:managed:end -->';

interface SyncOptions {
  readonly dryRun: boolean;
  readonly target: string;
}

function printHelp(): void {
  console.log(`Usage: lazykimi sync [options]

Update an existing LazyKimi installation with the current plugin templates.
Copies missing files and updates managed blocks in place. Files that are
user-owned (changed since install and containing no managed blocks) are
skipped. Runtime state under .lazykimi/state/ is never modified.

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

function hasManagedBlocks(content: string): boolean {
  return content.includes(MANAGED_START) && content.includes(MANAGED_END);
}

function extractManagedBlocks(content: string): string[] {
  const blocks: string[] = [];
  const pattern = new RegExp(`${escapeRegex(MANAGED_START)}[\\s\\S]*?${escapeRegex(MANAGED_END)}`, 'g');
  let match: RegExpExecArray | null;
  while ((match = pattern.exec(content)) !== null) {
    blocks.push(match[0]);
  }
  return blocks;
}

function escapeRegex(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function mergeManagedBlocks(targetContent: string, sourceContent: string): string {
  const sourceBlocks = extractManagedBlocks(sourceContent);
  if (sourceBlocks.length === 0) {
    // Nothing to merge; leave target unchanged.
    return targetContent;
  }
  let index = 0;
  let merged = targetContent.replace(
    new RegExp(`${escapeRegex(MANAGED_START)}[\\s\\S]*?${escapeRegex(MANAGED_END)}`, 'g'),
    (match) => {
      if (index < sourceBlocks.length) {
        return sourceBlocks[index++];
      }
      // Source has fewer blocks than target; preserve the extra target block
      // to avoid deleting user-adjacent content.
      return match;
    },
  );
  if (index < sourceBlocks.length) {
    merged += '\n' + sourceBlocks.slice(index).join('\n');
  }
  return merged;
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

  const targetContent = readFileSync(destPath, 'utf-8');
  const targetHash = sha256OfFile(destPath);
  const receiptHash = receiptHashes.get(rel);
  const unchangedFromReceipt = receiptHash !== undefined && receiptHash === targetHash;

  if (unchangedFromReceipt) {
    actions.push(`unchanged ${rel}`);
    return;
  }

  if (hasManagedBlocks(targetContent)) {
    const sourceContent = readFileSync(srcPath, 'utf-8');
    if (!hasManagedBlocks(sourceContent)) {
      // Source template has no managed blocks, so we cannot safely preserve
      // user-owned surrounding content. Treat as user-owned.
      actions.push(`skip ${rel} (user-owned)`);
      return;
    }
    const merged = mergeManagedBlocks(targetContent, sourceContent);
    if (merged === targetContent) {
      actions.push(`unchanged ${rel}`);
      return;
    }
    if (!dryRun) writeFileSync(destPath, merged, 'utf-8');
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

  // Rewrite MCP server paths only if mcp.json was actually synced.
  if (synced.includes('.kimi-code/mcp.json')) {
    rewriteMcpPaths(target, opts.dryRun, actions);
  }

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
  const receiptFiles = new Set(receipt.files.map(f => f.path));
  for (const rel of Array.from(receiptFiles)) {
    if (!existsSync(path.join(target, rel))) receiptFiles.delete(rel);
  }
  for (const rel of synced) receiptFiles.add(rel);

  if (!opts.dryRun) {
    writeReceipt(target, Array.from(receiptFiles), PLUGIN_VERSION);
    actions.push('write .kimi-code/.lazykimi-receipt.json');
  }

  console.log('\n=== Actions ===');
  for (const a of actions) console.log(`  ${opts.dryRun ? '[dry-run] ' : ''}${a}`);
  console.log(`\n${opts.dryRun ? 'Preview complete' : 'Sync complete'}. ${synced.length} file(s) ${opts.dryRun ? 'would be ' : ''}updated.`);
  return 0;
}
