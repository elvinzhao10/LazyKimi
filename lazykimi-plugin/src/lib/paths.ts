import path from 'path';
import { homedir } from 'os';

export function getPluginRoot(): string {
  // paths.ts compiles to dist/lib/paths.js. __dirname at runtime is dist/lib/.
  // Plugin root is two levels up: dist/lib -> dist -> <plugin root>.
  return path.resolve(__dirname, '..', '..');
}

export function getPluginKimiCodeDir(): string {
  return path.join(getPluginRoot(), '.kimi-code');
}

export function getPluginAgentsDir(): string {
  return path.join(getPluginRoot(), 'agents');
}

export function getPluginHooksDir(): string {
  return path.join(getPluginRoot(), 'hooks');
}

export function getHomeDir(): string {
  return homedir();
}

export function getKimiConfigDir(): string {
  return path.join(homedir(), '.kimi-code');
}

export function getKimiConfigFile(): string {
  return path.join(getKimiConfigDir(), 'config.toml');
}

export function detectTargetRoot(target?: string): string {
  return target ? path.resolve(target) : process.cwd();
}
