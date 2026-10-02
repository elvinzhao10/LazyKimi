import { existsSync, unlinkSync, readFileSync } from 'fs';
import path from 'path';
import { getKimiConfigFile } from '../lib/paths';
import { removeHooksFromConfig } from '../lib/hooks-config';
import { isFileModified, listInstalledFiles, readReceipt, safeProjectPath, serverDigest } from '../lib/receipt';
import { readJson, writeJson, isObject } from '../lib/json';

const PLUGIN_VERSION = '1.3.5';

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
  try { unlinkSync(abs); } catch (error) {
    if (isObject(error) && error.code === 'ENOENT') return;
    throw error;
  }
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
    const result = removeHooksFromConfig(configFile, target);
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

  const receipt = readReceipt(target);
  const installedFiles = listInstalledFiles(target);
  const ownedHookPaths = installedFiles.filter(rel => rel.startsWith('.kimi-code/hooks/') && !isFileModified(target, rel, receipt)).map(rel => path.join(target, rel));
  const kimiCodeDir = path.join(target, '.kimi-code');

  if (receipt) {
    // Inventory the entire receipt before the first deletion.
    const deletable = installedFiles.filter(rel => !isFileModified(target, rel, receipt));
    for (const rel of installedFiles) {
      const abs = path.join(target, rel);
      if (!existsSync(abs)) continue;
      if (!deletable.includes(rel)) {
        preserved.push(rel);
        continue;
      }
      removeFile(abs);
      removed.push(rel);
    }
    const mcpPath = path.join(kimiCodeDir, 'mcp.json');
    if (safeProjectPath(target, '.kimi-code/mcp.json') && existsSync(mcpPath) && receipt.mcpServers) {
      try {
        const current = readJson(mcpPath);
        if (isObject(current) && isObject(current.mcpServers)) {
          for (const [name, digest] of Object.entries(receipt.mcpServers)) {
            if (Object.hasOwn(current.mcpServers, name) && serverDigest(current.mcpServers[name]) === digest) { delete current.mcpServers[name]; removed.push(`MCP ${name}`); }
            else preserved.push(`MCP ${name}`);
          }
          writeJson(mcpPath, current);
        }
      } catch (error) { if (error instanceof SyntaxError) preserved.push('.kimi-code/mcp.json'); else throw error; }
    }
    if (preserved.length === 0) removeFile(path.join(kimiCodeDir, '.lazykimi-receipt.json'));
  } else if (existsSync(kimiCodeDir)) {
    console.log('No valid receipt found. Preserving .kimi-code/ and host configuration.');
    preserved.push('.kimi-code/');
  }

  if (opts.purgeState) {
    const lazykimiDir = path.join(target, '.lazykimi');
    if (existsSync(lazykimiDir)) {
      preserved.push('.lazykimi/ (state is not receipt-owned)');
    }
  }

  const hookResult = receipt && ownedHookPaths.length > 0 ? removeHooksFromConfig(getKimiConfigFile(), target, ownedHookPaths) : { changed: false };
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
