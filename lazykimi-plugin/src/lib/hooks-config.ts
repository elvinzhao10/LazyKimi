import { existsSync, readFileSync, realpathSync, writeFileSync } from 'fs';
import path from 'path';
import { getPluginHooksDir } from './paths';

export interface HookResult {
  readonly changed: boolean;
  readonly reason?: string;
}

function extractCommand(blockLines: readonly string[]): string | undefined {
  for (const line of blockLines) {
    const match = line.match(/^command\s*=\s*"([^"]+)"\s*$/);
    if (match) {
      return match[1];
    }
  }
  return undefined;
}

/**
 * Resolve a path to its real path, resolving symlinks for the longest existing
 * prefix and leaving the non-existent suffix unchanged. This lets us compare a
 * hook command path (which may reference files already deleted during uninstall)
 * against the project root even when one was recorded through a symlink.
 */
function resolvePathPreservingSuffix(filePath: string): string {
  const resolved = path.resolve(filePath);
  const parts = resolved.split(path.sep);
  for (let i = parts.length; i > 0; i -= 1) {
    const prefix = parts.slice(0, i).join(path.sep) || path.sep;
    if (existsSync(prefix)) {
      try {
        const realPrefix = realpathSync(prefix);
        const suffix = parts.slice(i).join(path.sep);
        return suffix ? path.join(realPrefix, suffix) : realPrefix;
      } catch {
        // Fall through to the next shorter prefix.
      }
    }
  }
  return resolved;
}

function isLazyKimiCommand(command: string, projectRoot: string): boolean {
  const scriptPath = command.startsWith('bash ') ? command.slice(5) : command;
  try {
    const resolvedScript = resolvePathPreservingSuffix(scriptPath);
    const resolvedRoot = realpathSync(path.resolve(projectRoot));
    const projectHooksDir = path.join(resolvedRoot, '.kimi-code', 'hooks') + path.sep;
    const sourceHooksDir = path.join(resolvedRoot, 'hooks') + path.sep;
    return resolvedScript.startsWith(projectHooksDir) || resolvedScript.startsWith(sourceHooksDir);
  } catch {
    return false;
  }
}

function isLazyKimiBlock(blockLines: readonly string[]): boolean {
  const command = extractCommand(blockLines);
  if (!command) return false;
  const scriptPath = command.startsWith('bash ') ? command.slice(5) : command;
  try {
    const resolvedScript = resolvePathPreservingSuffix(scriptPath);
    const pluginHooksDir = realpathSync(getPluginHooksDir()) + path.sep;
    const projectHooksPattern = path.sep + '.kimi-code' + path.sep + 'hooks' + path.sep;
    return resolvedScript.includes(projectHooksPattern) || resolvedScript.startsWith(pluginHooksDir);
  } catch {
    return false;
  }
}

export function isHooksInstalled(configPath: string): boolean {
  if (!existsSync(configPath)) return false;
  const content = readFileSync(configPath, 'utf-8');
  const lines = content.split('\n');
  let i = 0;
  while (i < lines.length) {
    if (lines[i].trim() === '[[hooks]]') {
      const start = i;
      i += 1;
      while (i < lines.length && lines[i].trim() !== '[[hooks]]') {
        i += 1;
      }
      if (isLazyKimiBlock(lines.slice(start, i))) {
        return true;
      }
    } else {
      i += 1;
    }
  }
  return false;
}

export function removeHooksFromConfig(configPath: string, projectRoot: string): HookResult {
  if (!existsSync(configPath)) {
    return { changed: false, reason: 'config file not found' };
  }
  const content = readFileSync(configPath, 'utf-8');
  const lines = content.split('\n');
  const result: string[] = [];
  let i = 0;
  let removedCount = 0;

  while (i < lines.length) {
    if (lines[i].trim() === '[[hooks]]') {
      const start = i;
      i += 1;
      while (i < lines.length && lines[i].trim() !== '[[hooks]]') {
        i += 1;
      }
      const blockLines = lines.slice(start, i);
      const command = extractCommand(blockLines);
      const shouldRemove = command !== undefined && isLazyKimiCommand(command, projectRoot);
      if (shouldRemove) {
        removedCount += 1;
      } else {
        result.push(...blockLines);
      }
    } else {
      result.push(lines[i]);
      i += 1;
    }
  }

  if (removedCount === 0) {
    return { changed: false, reason: 'no LazyKimi hooks found' };
  }

  while (result.length > 0 && result[result.length - 1] === '') {
    result.pop();
  }

  writeFileSync(configPath, result.length > 0 ? result.join('\n') + '\n' : '', 'utf-8');
  return { changed: true, reason: `removed ${removedCount} LazyKimi hook block(s)` };
}


