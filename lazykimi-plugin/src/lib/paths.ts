import path from 'path';
import { homedir } from 'os';
import { existsSync } from 'fs';

export function getPluginRoot(): string {
  // paths.ts compiles to dist/lib/paths.js. __dirname at runtime is dist/lib/.
  // Plugin root is two levels up: dist/lib -> dist -> <plugin root>.
  return path.resolve(__dirname, '..', '..');
}

export function isPluginSourceRoot(dir: string): boolean {
  return (
    existsSync(path.join(dir, 'package.json')) &&
    existsSync(path.join(dir, 'kimi.plugin.json')) &&
    existsSync(path.join(dir, 'src'))
  );
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

export function getPluginCommandsDir(): string {
  return path.join(getPluginRoot(), 'commands');
}

export function getPluginContractsDir(): string {
  return path.join(getPluginRoot(), 'contracts');
}

export function getPluginToolingDir(): string {
  return path.join(getPluginRoot(), 'tooling');
}

export function getPluginRulesDir(): string {
  return path.join(getPluginRoot(), '.kimi-code', 'rules');
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
