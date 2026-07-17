import { existsSync, readFileSync, writeFileSync, mkdirSync } from 'fs';
import path from 'path';
import { getPluginHooksDir } from './paths';

const MARKER = '# LazyKimi hooks for Kimi Code CLI';

export function getHooksConfigContent(): string {
  const templatePath = path.join(getPluginHooksDir(), 'hooks-config.toml');
  if (!existsSync(templatePath)) {
    throw new Error(`hooks-config.toml not found at ${templatePath}`);
  }
  return readFileSync(templatePath, 'utf-8');
}

export function isHooksInstalled(configPath: string): boolean {
  if (!existsSync(configPath)) return false;
  const content = readFileSync(configPath, 'utf-8');
  return content.includes(MARKER);
}

export interface HookResult {
  readonly changed: boolean;
  readonly reason?: string;
}

export function appendHooksToConfig(configPath: string): HookResult {
  const dir = path.dirname(configPath);
  mkdirSync(dir, { recursive: true });
  if (!existsSync(configPath)) {
    writeFileSync(configPath, '', 'utf-8');
  }
  if (isHooksInstalled(configPath)) {
    return { changed: false, reason: 'hooks already present' };
  }
  let content = readFileSync(configPath, 'utf-8');
  if (content.length > 0 && !content.endsWith('\n')) {
    content += '\n';
  }
  content += getHooksConfigContent();
  if (!content.endsWith('\n')) content += '\n';
  writeFileSync(configPath, content, 'utf-8');
  return { changed: true };
}

export function removeHooksFromConfig(configPath: string): HookResult {
  if (!existsSync(configPath)) {
    return { changed: false, reason: 'config file not found' };
  }
  const content = readFileSync(configPath, 'utf-8');
  const idx = content.indexOf(MARKER);
  if (idx === -1) {
    return { changed: false, reason: 'hooks marker not found' };
  }
  // The hooks block is always appended last; remove from marker to end of file.
  const before = content.slice(0, idx).replace(/\n+$/, '\n');
  writeFileSync(configPath, before, 'utf-8');
  return { changed: true };
}

export function countHooksEntries(): number {
  try {
    const content = getHooksConfigContent();
    const matches = content.match(/^\[\[hooks\]\]/gm);
    return matches ? matches.length : 0;
  } catch {
    return 0;
  }
}
