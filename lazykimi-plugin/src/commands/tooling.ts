import { existsSync, readFileSync, writeFileSync, mkdirSync } from 'fs';
import path from 'path';
import { spawnSync } from 'child_process';
import { getPluginToolingDir } from '../lib/paths';

const OPTIONAL_CAPABILITIES: ReadonlyArray<string> = [
  'grep_app',
  'context7',
  'filesystem',
  'git',
  'playwright',
  'ast_grep',
  'lsp',
];

function serverNameForCapability(capability: string): string {
  return `lazykimi-${capability.replace(/_/g, '-')}`;
}

function capabilityPlaceholder(capability: string): unknown {
  return {
    command: 'bash',
    args: [`__LAZYKIMI_OPTIONAL_${capability.toUpperCase()}_NOT_IMPLEMENTED__`],
    cwd: '.',
    required: false,
  };
}

function getProjectMcpPath(): string {
  return path.join(process.cwd(), '.kimi-code', 'mcp.json');
}

function loadMcpConfig(mcpPath: string): { mcpServers: Record<string, unknown> } {
  if (!existsSync(mcpPath)) {
    return { mcpServers: {} };
  }
  try {
    const raw = readFileSync(mcpPath, 'utf-8');
    const parsed = JSON.parse(raw) as { mcpServers?: Record<string, unknown> };
    return { mcpServers: parsed.mcpServers ?? {} };
  } catch (err) {
    console.error(`lazykimi tooling: failed to parse ${mcpPath}: ${err instanceof Error ? err.message : String(err)}`);
    process.exit(1);
  }
}

function saveMcpConfig(mcpPath: string, config: { mcpServers: Record<string, unknown> }): void {
  mkdirSync(path.dirname(mcpPath), { recursive: true });
  writeFileSync(mcpPath, JSON.stringify(config, null, 2) + '\n', 'utf-8');
}

function isValidCapability(capability: string): boolean {
  return OPTIONAL_CAPABILITIES.includes(capability);
}

function runEnable(args: string[]): number {
  if (args.length === 0) {
    console.error('lazykimi tooling enable: missing capability name');
    return 1;
  }
  const capability = args[0];
  if (!isValidCapability(capability)) {
    console.error(`lazykimi tooling enable: unsupported capability '${capability}'`);
    console.error(`Supported: ${OPTIONAL_CAPABILITIES.join(', ')}`);
    return 1;
  }

  const mcpPath = getProjectMcpPath();
  const config = loadMcpConfig(mcpPath);
  const serverName = serverNameForCapability(capability);

  if (config.mcpServers[serverName]) {
    console.log(`${capability}: already enabled (${serverName})`);
    return 0;
  }

  config.mcpServers[serverName] = capabilityPlaceholder(capability);
  saveMcpConfig(mcpPath, config);
  console.log(`${capability}: enabled (${serverName})`);
  return 0;
}

function runDisable(args: string[]): number {
  if (args.length === 0) {
    console.error('lazykimi tooling disable: missing capability name');
    return 1;
  }
  const capability = args[0];
  if (!isValidCapability(capability)) {
    console.error(`lazykimi tooling disable: unsupported capability '${capability}'`);
    console.error(`Supported: ${OPTIONAL_CAPABILITIES.join(', ')}`);
    return 1;
  }

  const mcpPath = getProjectMcpPath();
  const config = loadMcpConfig(mcpPath);
  const serverName = serverNameForCapability(capability);

  if (!config.mcpServers[serverName]) {
    console.log(`${capability}: not enabled`);
    return 0;
  }

  delete config.mcpServers[serverName];
  saveMcpConfig(mcpPath, config);
  console.log(`${capability}: disabled`);
  return 0;
}

function runList(): number {
  const mcpPath = getProjectMcpPath();
  const config = loadMcpConfig(mcpPath);
  for (const capability of OPTIONAL_CAPABILITIES) {
    const serverName = serverNameForCapability(capability);
    const status = config.mcpServers[serverName] ? 'enabled' : 'disabled';
    console.log(`${capability}: ${status}`);
  }
  return 0;
}

function resolveToolingDir(): string {
  const cwdTooling = path.join(process.cwd(), '.kimi-code', 'tooling');
  if (existsSync(path.join(cwdTooling, 'lazykimi_detector.py'))) {
    return cwdTooling;
  }
  return getPluginToolingDir();
}

function runPythonScript(name: string): number {
  const script = path.join(resolveToolingDir(), name);
  if (!existsSync(script)) {
    console.error(`lazykimi tooling: script not found: ${script}`);
    return 1;
  }

  const result = spawnSync('python3', [script], {
    encoding: 'utf-8',
    stdio: 'pipe',
  });

  if (result.error) {
    console.error(`lazykimi tooling: failed to run python3: ${result.error.message}`);
    return 1;
  }
  if (result.status !== 0) {
    console.error(result.stderr || `lazykimi tooling: ${name} exited ${result.status ?? 'unknown'}`);
    return result.status ?? 1;
  }

  const stdout = result.stdout || '';
  try {
    const parsed = JSON.parse(stdout);
    console.log(JSON.stringify(parsed, null, 2));
  } catch {
    console.log(stdout);
  }
  return 0;
}

function printHelp(): void {
  console.log(`Usage: lazykimi tooling <subcommand>

Query the receipt-owned tooling capability broker.

Subcommands:
  detect   Print capability detection results for host-installed tools
  status   Print overall capability status and detected tools
  policy   Print the tooling policy digest and permission defaults
  enable   <capability>  Enable an optional MCP capability placeholder
  disable  <capability>  Disable an optional MCP capability placeholder
  list     Show enabled/disabled optional MCP capabilities

Optional capabilities:
  ${OPTIONAL_CAPABILITIES.join(', ')}

Options:
  --help, -h   Show this help message`);
}

export function run(args: string[]): number {
  if (args.length === 0 || args.includes('--help') || args.includes('-h')) {
    printHelp();
    return 0;
  }

  const subcommand = args[0];
  switch (subcommand) {
    case 'detect':
      return runPythonScript('lazykimi_detector.py');
    case 'status':
      return runPythonScript('lazykimi_capability.py');
    case 'policy':
      return runPythonScript('lazykimi_policy.py');
    case 'enable':
      return runEnable(args.slice(1));
    case 'disable':
      return runDisable(args.slice(1));
    case 'list':
      return runList();
    default:
      console.error(`lazykimi tooling: unknown subcommand '${subcommand}'`);
      printHelp();
      return 1;
  }
}
