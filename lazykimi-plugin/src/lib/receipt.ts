import { createHash } from 'crypto';
import { readFileSync, existsSync, statSync } from 'fs';
import path from 'path';
import { readJson, writeJson, isObject } from './json';

const RECEIPT_FILENAME = '.lazykimi-receipt.json';

interface ReceiptEntry {
  readonly path: string;
  readonly sha256: string;
  readonly size: number;
}

interface Receipt {
  readonly version: number;
  readonly installedAt: string;
  readonly pluginVersion: string;
  readonly files: ReceiptEntry[];
}

export function getReceiptPath(targetRoot: string): string {
  return path.join(targetRoot, '.kimi-code', RECEIPT_FILENAME);
}

export function sha256OfFile(filePath: string): string {
  const content = readFileSync(filePath);
  return createHash('sha256').update(content).digest('hex');
}

export function writeReceipt(targetRoot: string, files: string[], pluginVersion: string): void {
  const entries: ReceiptEntry[] = files.map(rel => {
    const abs = path.join(targetRoot, rel);
    const stat = statSync(abs);
    return { path: rel, sha256: sha256OfFile(abs), size: stat.size };
  });
  const receipt: Receipt = {
    version: 1,
    installedAt: new Date().toISOString(),
    pluginVersion,
    files: entries,
  };
  writeJson(getReceiptPath(targetRoot), receipt);
}

function isReceiptEntry(value: unknown): value is ReceiptEntry {
  return isObject(value)
    && typeof value.path === 'string'
    && typeof value.sha256 === 'string'
    && typeof value.size === 'number';
}

export function readReceipt(targetRoot: string): Receipt | null {
  const p = getReceiptPath(targetRoot);
  if (!existsSync(p)) return null;
  const data = readJson(p);
  if (!isObject(data)) return null;
  const rawFiles = Array.isArray(data.files) ? data.files : [];
  return {
    version: typeof data.version === 'number' ? data.version : 1,
    installedAt: typeof data.installedAt === 'string' ? data.installedAt : '',
    pluginVersion: typeof data.pluginVersion === 'string' ? data.pluginVersion : '',
    files: rawFiles.filter(isReceiptEntry),
  };
}

export function isFileModified(targetRoot: string, relPath: string): boolean {
  const receipt = readReceipt(targetRoot);
  if (!receipt) return true;
  const entry = receipt.files.find(f => f.path === relPath);
  if (!entry) return true;
  const abs = path.join(targetRoot, relPath);
  if (!existsSync(abs)) return false;
  return sha256OfFile(abs) !== entry.sha256;
}

export function listInstalledFiles(targetRoot: string): string[] {
  const receipt = readReceipt(targetRoot);
  if (!receipt) return [];
  return receipt.files.map(f => f.path);
}

export function receiptExists(targetRoot: string): boolean {
  return existsSync(getReceiptPath(targetRoot));
}
