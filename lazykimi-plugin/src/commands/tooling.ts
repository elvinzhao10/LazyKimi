import { existsSync } from 'fs';
import path from 'path';
import { spawnSync } from 'child_process';
import { getPluginToolingDir } from '../lib/paths';

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
    default:
      console.error(`lazykimi tooling: unknown subcommand '${subcommand}'`);
      printHelp();
      return 1;
  }
}
