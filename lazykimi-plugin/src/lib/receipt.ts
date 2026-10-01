import { createHash } from 'crypto';
import { readFileSync, existsSync, lstatSync, realpathSync } from 'fs';
import path from 'path';
import { readJson, writeJson, isObject } from './json';

const RECEIPT_FILENAME = '.lazykimi-receipt.json';
export interface ReceiptEntry {
  readonly path: string;
  readonly sha256: string;
  readonly size: number;
}
export interface Receipt {
  readonly version: number;
  readonly installedAt: string;
  readonly pluginVersion: string;
  readonly files: readonly ReceiptEntry[];
  readonly mcpServers?: Readonly<Record<string, string>>;
}
export function getReceiptPath(targetRoot: string): string {
  return path.join(targetRoot, '.kimi-code', RECEIPT_FILENAME);
}
export function safeProjectPath(targetRoot: string, relative: string): boolean {
  if (path.isAbsolute(relative) || relative.includes('\\') || relative.split('/').some(p => !p || p === '.' || p === '..')) return false;
  if (!relative.startsWith('.kimi-code/') && !relative.startsWith('.lazykimi/')) return false;
  let current = path.resolve(targetRoot);
  let ancestor = path.parse(current).root;
  for (const component of current.split(path.sep).filter(Boolean)) {
    ancestor = path.join(ancestor, component);
    try {
      const stat = lstatSync(ancestor);
      // macOS exposes its canonical temporary tree through /var.
      if (stat.isSymbolicLink() && !(ancestor === '/var' && realpathSync(ancestor) === '/private/var')) return false;
      if (!stat.isDirectory() && !stat.isSymbolicLink()) return false;
    } catch (error) {
      if (isObject(error) && error.code === 'ENOENT') continue;
      throw error;
    }
  }
  const parts = relative.split('/');
  for (let i = 0; i < parts.length; i++) {
    current = path.join(current, parts[i]);
    try {
      const stat = lstatSync(current);
      if (stat.isSymbolicLink() || (i < parts.length - 1 && !stat.isDirectory()) || (stat.isFile() && stat.nlink !== 1)) return false;
    } catch (error) {
      if (isObject(error) && error.code === 'ENOENT') continue;
      throw error;
    }
  }
  return true;
}
export function sha256OfFile(filePath: string): string {
  return createHash('sha256').update(readFileSync(filePath)).digest('hex');
}
export function serverDigest(server: unknown): string {
  return createHash('sha256').update(JSON.stringify(server)).digest('hex');
}
export function writeReceipt(targetRoot: string, files: string[], pluginVersion: string, mcpServers: Readonly<Record<string, string>> = {}): void {
  const entries = [...new Set(files)].map(rel => {
    const abs = path.join(targetRoot, rel);
    return { path: rel, sha256: sha256OfFile(abs), size: lstatSync(abs).size };
  });
  writeJson(getReceiptPath(targetRoot), { version: 1, installedAt: new Date().toISOString(), pluginVersion, files: entries, mcpServers });
}
function isReceiptEntry(value: unknown): value is ReceiptEntry {
  return isObject(value) && typeof value.path === 'string'
    && Object.keys(value).every(key => ['path', 'sha256', 'size'].includes(key))
    && typeof value.sha256 === 'string' && /^[a-f0-9]{64}$/.test(value.sha256)
    && typeof value.size === 'number' && Number.isSafeInteger(value.size) && value.size >= 0;
}
export function readReceipt(targetRoot: string): Receipt | null {
  const relative = `.kimi-code/${RECEIPT_FILENAME}`;
  if (!safeProjectPath(targetRoot, relative) || !existsSync(getReceiptPath(targetRoot))) return null;
  let data: unknown;
  try { data = readJson(getReceiptPath(targetRoot)); }
  catch (error) { if (error instanceof SyntaxError) return null; throw error; }
  if (!isObject(data) || Object.keys(data).some(key => !['version', 'installedAt', 'pluginVersion', 'files', 'mcpServers'].includes(key))
    || data.version !== 1 || typeof data.installedAt !== 'string' || !data.installedAt || typeof data.pluginVersion !== 'string' || !data.pluginVersion
    || !Array.isArray(data.files) || !data.files.every(isReceiptEntry)) return null;
  const files: ReceiptEntry[] = data.files;
  if (new Set(files.map(f => f.path)).size !== files.length
    || files.some(f => f.path === relative || !safeProjectPath(targetRoot, f.path)
      || (existsSync(path.join(targetRoot, f.path)) && !lstatSync(path.join(targetRoot, f.path)).isFile()))) return null;
  if (data.mcpServers !== undefined && (!isObject(data.mcpServers) || Object.entries(data.mcpServers).some(([key, digest]) =>
    !/^lazykimi-[a-z-]+$/.test(key) || typeof digest !== 'string' || !/^[a-f0-9]{64}$/.test(digest)))) return null;
  const mcpServers: Record<string, string> = {};
  if (isObject(data.mcpServers)) for (const [key, value] of Object.entries(data.mcpServers)) if (typeof value === 'string') mcpServers[key] = value;
  if (files.length === 0 && Object.keys(mcpServers).length === 0) return null;
  if (Object.keys(mcpServers).length > 0 && !safeProjectPath(targetRoot, '.kimi-code/mcp.json')) return null;
  return { version: 1, installedAt: data.installedAt, pluginVersion: data.pluginVersion, files, mcpServers };
}
export function isFileModified(targetRoot: string, relPath: string, receipt: Receipt | null = readReceipt(targetRoot)): boolean {
  const entry = receipt?.files.find(f => f.path === relPath);
  if (!entry || !safeProjectPath(targetRoot, relPath)) return true;
  const abs = path.join(targetRoot, relPath);
  if (!existsSync(abs)) return false;
  return !lstatSync(abs).isFile() || sha256OfFile(abs) !== entry.sha256 || lstatSync(abs).size !== entry.size;
}
export function listInstalledFiles(targetRoot: string): string[] {
  return readReceipt(targetRoot)?.files.map(f => f.path) ?? [];
}
export function receiptExists(targetRoot: string): boolean {
  return readReceipt(targetRoot) !== null;
}
