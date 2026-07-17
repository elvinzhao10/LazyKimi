import { readFileSync, writeFileSync, mkdirSync } from 'fs';
import path from 'path';

export function readJson(filePath: string): unknown {
  const content = readFileSync(filePath, 'utf-8');
  return JSON.parse(content);
}

export function tryReadJson(filePath: string): unknown {
  try {
    return readJson(filePath);
  } catch {
    return null;
  }
}

export function writeJson(filePath: string, data: unknown): void {
  mkdirSync(path.dirname(filePath), { recursive: true });
  writeFileSync(filePath, JSON.stringify(data, null, 2) + '\n', 'utf-8');
}

export function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

export function hasStringProperty(obj: unknown, key: string): boolean {
  return isObject(obj) && typeof obj[key] === 'string';
}

export function hasNumberProperty(obj: unknown, key: string): boolean {
  return isObject(obj) && typeof obj[key] === 'number';
}
