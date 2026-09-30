import { existsSync, readFileSync, writeFileSync, mkdirSync } from 'fs';
import path from 'path';
import { spawnSync } from 'child_process';
import { getPluginRoot, getPluginToolingDir } from '../lib/paths';

const OPTIONAL_CAPABILITIES: ReadonlyArray<string> = [
  'grep_app',
  'context7',
  'filesystem',
  'git',
  'playwright',
  'ast_grep',
  'lsp',
];

const CODEGRAPH_VERBS: ReadonlyArray<string> = [
  'codegraph-status',
  'codegraph-install',
  'codegraph-init',
  'codegraph-enable',
  'codegraph-doctor',
  'codegraph-uninstall',
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

function runPythonScript(name: string, args: string[] = []): number {
  const script = path.join(resolveToolingDir(), name);
  if (!existsSync(script)) {
    console.error(`lazykimi tooling: script not found: ${script}`);
    return 1;
  }

  const result = spawnSync('python3', [script, ...args], {
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

// --- Family capability surface (T13) ---------------------------------------

function findOption(args: string[], name: string): string | undefined {
  const index = args.indexOf(name);
  if (index === -1 || index + 1 >= args.length) {
    return undefined;
  }
  return args[index + 1];
}

/**
 * Resolve the receipt-owned tooling root the family surface reports against.
 * Precedence: explicit --tooling-root, LAZYKIMI_TOOLING_ROOT, then the
 * uninstalled sentinel (mirrors the family default: report honestly as
 * unavailable rather than fabricate a root).
 */
function resolveToolingRoot(args: string[]): string {
  const explicit = findOption(args, '--tooling-root');
  if (explicit) {
    return path.resolve(explicit);
  }
  const fromEnv = process.env.LAZYKIMI_TOOLING_ROOT;
  if (fromEnv) {
    return path.resolve(fromEnv);
  }
  return path.join(getPluginRoot(), '.lazykimi-readiness-uninitialized');
}

function runToolingScript(scriptArgs: string[]): number {
  const script = path.join(getPluginRoot(), 'scripts', 'lazykimi-tooling.sh');
  if (!existsSync(script)) {
    console.error(`lazykimi tooling: script not found: ${script}`);
    return 1;
  }
  const result = spawnSync('bash', [script, ...scriptArgs], {
    encoding: 'utf-8',
    stdio: 'pipe',
  });
  if (result.stdout) {
    process.stdout.write(result.stdout);
  }
  if (result.stderr) {
    process.stderr.write(result.stderr);
  }
  if (result.error) {
    console.error(`lazykimi tooling: failed to run lazykimi-tooling.sh: ${result.error.message}`);
    return 1;
  }
  return result.status ?? 1;
}

/** Readiness records + the v1.3.3 adaptive selection report (selection-only
 * until the kimi host is observed; the block is computed by the ported
 * lazykimi_adaptive_runtime mapping, never asserted by the CLI). */
function runCapabilityStatus(args: string[]): number {
  const asJson = args.includes('--json');
  const toolingRoot = resolveToolingRoot(args);
  const toolingDir = resolveToolingDir();

  const readiness = spawnSync(
    'python3',
    [path.join(toolingDir, 'lazykimi_capability_readiness.py'), 'readiness-report', '--tooling-root', toolingRoot, '--json'],
    { encoding: 'utf-8', stdio: 'pipe' },
  );
  if (readiness.error || readiness.status !== 0) {
    console.error(readiness.stderr || 'lazykimi tooling: capability readiness report failed');
    return readiness.status ?? 1;
  }

  const adaptiveScript = [
    'import json, sys',
    `sys.path.insert(0, ${JSON.stringify(toolingDir)})`,
    'from lazykimi_adaptive_runtime import _runtime_mapping',
    "decision = {'mode': 'orchestrated', 'approval_required': False, 'snapshot': {}, 'explicitWorkflow': None}",
    "mapping = _runtime_mapping(decision, False, 'kimi')",
    'print(json.dumps({',
    '  "host": "kimi",',
    '  "hostObserved": False,',
    '  "route": mapping["route"],',
    '  "hostReadiness": mapping["hostReadiness"],',
    '  "entryRoute": "explicit-start-work",',
    '  "reason": "v1.3.3 rule: the kimi host profile stays selection-only until a host observation receipt exists",',
    '}, sort_keys=True))',
  ].join('\n');
  const adaptive = spawnSync('python3', ['-c', adaptiveScript], { encoding: 'utf-8', stdio: 'pipe' });
  if (adaptive.error || adaptive.status !== 0) {
    console.error(adaptive.stderr || 'lazykimi tooling: adaptive selection report failed');
    return adaptive.status ?? 1;
  }

  try {
    const records = JSON.parse(readiness.stdout);
    const adaptiveBlock = JSON.parse(adaptive.stdout);
    const report = {
      tooling_root: toolingRoot,
      adaptive: adaptiveBlock,
      ...records,
    };
    if (asJson) {
      console.log(JSON.stringify(report, null, 2));
      return 0;
    }
    console.log(`TOOLING_ROOT: ${toolingRoot}`);
    console.log(`ADAPTIVE_ROUTE: ${adaptiveBlock.route} (host=${adaptiveBlock.host}, readiness=${adaptiveBlock.hostReadiness})`);
    for (const record of records.records ?? []) {
      const entry = record as { capability?: string; provider?: string; internal_status?: string };
      console.log(`CAPABILITY: ${entry.capability ?? '?'} PROVIDER: ${entry.provider ?? '?'} STATUS: ${entry.internal_status ?? '?'}`);
    }
    return 0;
  } catch (err) {
    console.error(`lazykimi tooling: capability-status failed to parse reports: ${err instanceof Error ? err.message : String(err)}`);
    return 1;
  }
}

function runCodegraph(verb: string, args: string[]): number {
  const target = findOption(args, '--target') ?? process.cwd();
  const toolingRoot = findOption(args, '--tooling-root') ?? process.env.LAZYKIMI_TOOLING_ROOT;
  if (!toolingRoot) {
    console.error('lazykimi tooling: codegraph lifecycle requires --tooling-root or LAZYKIMI_TOOLING_ROOT');
    console.error('CodeGraph stays disabled until a caller explicitly installs it (family rule).');
    return 1;
  }
  return runToolingScript([verb, '--target', path.resolve(target), '--tooling-root', path.resolve(toolingRoot)]);
}

function printHelp(): void {
  console.log(`Usage: lazykimi tooling <subcommand>

Query the receipt-owned tooling capability broker and the family
capability surface.

Subcommands:
  capability-status [--json] [--tooling-root DIR]
                       Capability readiness records plus the v1.3.3 adaptive
                       selection report (selection-only until the kimi host
                       is observed)
  detect [--tooling-root DIR]
                       Tooling root status, registry, and provider detection
  policy               Tooling policy provider report (JSON)
  codegraph-status     CodeGraph receipt/index state (explicit capability)
  codegraph-install    Provision the pinned CodeGraph package (absent root only)
  codegraph-init       Initialize the project-local CodeGraph index
  codegraph-enable     Enable the initialized index explicitly
  codegraph-doctor     CodeGraph status + sizing recommendation
  codegraph-uninstall  Receipt-gated removal (caller-created index survives)
  enable   <capability>  Enable an optional MCP capability placeholder
  disable  <capability>  Disable an optional MCP capability placeholder
  list     Show enabled/disabled optional MCP capabilities

Codegraph verbs accept --target DIR (default: cwd) and require
--tooling-root DIR or LAZYKIMI_TOOLING_ROOT.

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
  const rest = args.slice(1);
  switch (subcommand) {
    case 'capability-status':
    case 'status':
      return runCapabilityStatus(rest);
    case 'detect':
      return runToolingScript(['detect', '--tooling-root', resolveToolingRoot(rest)]);
    case 'policy':
      return runPythonScript('lazykimi_policy.py', ['providers', '--json']);
    case 'enable':
      return runEnable(rest);
    case 'disable':
      return runDisable(rest);
    case 'list':
      return runList();
    default:
      if ((CODEGRAPH_VERBS as readonly string[]).includes(subcommand)) {
        return runCodegraph(subcommand, rest);
      }
      console.error(`lazykimi tooling: unknown subcommand '${subcommand}'`);
      printHelp();
      return 1;
  }
}
