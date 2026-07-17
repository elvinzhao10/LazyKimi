import { existsSync, readdirSync, unlinkSync, rmdirSync, readFileSync } from 'fs';
import path from 'path';
import { getKimiConfigFile } from '../lib/paths';
import { removeHooksFromConfig } from '../lib/hooks-config';
import { isFileModified, listInstalledFiles, receiptExists } from '../lib/receipt';

const PLUGIN_VERSION = '0.1.0';

interface UninstallOptions {
  readonly soft: boolean;
  readonly purgeState: boolean;
  readonly yes: boolean;
}

function printHelp(): void {
  console.log(`Usage: lazykimi uninstall [options]

Remove LazyKimi from the current directory.

Options:
  --help, -h      Show this help message
  --soft          Remove hooks from config.toml only (keep .kimi-code/)
  --purge-state   Also remove .lazykimi/
  --yes           Skip confirmation`);
}

function parseArgs(args: string[]): UninstallOptions {
  let soft = false;
  let purgeState = false;
  let yes = false;
  for (const a of args) {
    if (a === '--help' || a === '-h') { printHelp(); process.exit(0); }
    else if (a === '--soft') soft = true;
    else if (a === '--purge-state') purgeState = true;
    else if (a === '--yes') yes = true;
  }
  return { soft, purgeState, yes };
}

function confirm(message: string, opts: UninstallOptions): boolean {
  if (opts.yes) return true;
  process.stdout.write(`${message} [y/N] `);
  try {
    const answer = readFileSync(0, 'utf-8').trim().toLowerCase();
    return answer === 'y' || answer === 'yes';
  } catch {
    return false;
  }
}

function removeFile(abs: string): void {
  try { unlinkSync(abs); } catch { /* ignore */ }
}

function removeDirIfEmpty(dir: string): void {
  try { rmdirSync(dir); } catch { /* not empty or missing */ }
}

function removeTree(dir: string): void {
  if (!existsSync(dir)) return;
  const entries = readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      removeTree(full);
    } else {
      removeFile(full);
    }
  }
  removeDirIfEmpty(dir);
}

export function run(args: string[]): number {
  const opts = parseArgs(args);
  const target = process.cwd();
  const removed: string[] = [];
  const preserved: string[] = [];

  console.log(`LazyKimi uninstall v${PLUGIN_VERSION}`);
  console.log(`Target: ${target}\n`);

  if (opts.soft) {
    const configFile = getKimiConfigFile();
    const result = removeHooksFromConfig(configFile);
    if (result.changed) {
      console.log(`Removed hooks from ${configFile}`);
    } else {
      console.log(`No hooks removed: ${result.reason}`);
    }
    console.log('\nSoft uninstall complete. .kimi-code/ preserved.');
    return 0;
  }

  if (!confirm(`Remove LazyKimi .kimi-code/ from ${target}?`, opts)) {
    console.log('Cancelled.');
    return 0;
  }

  const hasReceipt = receiptExists(target);
  const installedFiles = listInstalledFiles(target);
  const kimiCodeDir = path.join(target, '.kimi-code');

  if (hasReceipt && installedFiles.length > 0) {
    for (const rel of installedFiles) {
      const abs = path.join(target, rel);
      if (!existsSync(abs)) continue;
      if (isFileModified(target, rel)) {
        preserved.push(rel);
        continue;
      }
      removeFile(abs);
      removed.push(rel);
    }
    removeFile(path.join(kimiCodeDir, '.lazykimi-receipt.json'));
  } else if (existsSync(kimiCodeDir)) {
    console.log('No receipt found. Removing entire .kimi-code/ directory.');
    removeTree(kimiCodeDir);
    removed.push('.kimi-code/');
  }

  if (opts.purgeState) {
    const lazykimiDir = path.join(target, '.lazykimi');
    if (existsSync(lazykimiDir)) {
      removeTree(lazykimiDir);
      removed.push('.lazykimi/');
    }
  }

  const hookResult = removeHooksFromConfig(getKimiConfigFile());
  if (hookResult.changed) removed.push('hooks from ~/.kimi-code/config.toml');

  console.log('=== Removed ===');
  for (const r of removed) console.log(`  - ${r}`);
  if (preserved.length > 0) {
    console.log('\n=== Preserved (modified or user-owned) ===');
    for (const p of preserved) console.log(`  + ${p}`);
  }
  console.log(`\nUninstall complete. ${removed.length} item(s) removed, ${preserved.length} preserved.`);
  if (!opts.purgeState) {
    console.log('.lazykimi/ state preserved. Use --purge-state to remove it.');
  }
  return 0;
}
