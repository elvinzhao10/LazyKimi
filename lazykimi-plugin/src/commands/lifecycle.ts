import { existsSync } from 'fs';
import path from 'path';
import { spawnSync } from 'child_process';
import { getPluginRoot } from '../lib/paths';

/**
 * `lazykimi lifecycle <onboard|update|status|offboard|recover-bootstrap-lock>`
 *
 * Delegates to the family durable-lifecycle CLI (scripts/lifecycle/cli.js)
 * under the durable install root (~/Library/Application Support/LazySeries/
 * LazyKimi by default; override with LAZYKIMI_INSTALL_ROOT or --install-root).
 * Onboard/update bootstrap only from the verified origin
 * https://github.com/elvinzhao10/LazyKimi.git — until that remote exists they
 * fail honestly. The project route (init/uninstall) is unaffected.
 */

const LIFECYCLE_COMMANDS = ['onboard', 'update', 'status', 'offboard', 'recover-bootstrap-lock'];

function printHelp(): void {
  const lifecycleCli = path.join(getPluginRoot(), 'scripts', 'lazykimi-lifecycle.js');
  console.log(`Usage: lazykimi lifecycle <command> [options]

Durable LazyKimi lifecycle under the LazySeries install root.

Commands:
  onboard                Verify and install an official LazyKimi release
  update                 Verify and promote an official LazyKimi revision
  status                 Inspect durable package and host-readiness state
  offboard               Plan or remove exact receipt-owned LazyKimi state
  recover-bootstrap-lock Recover a verified stale sibling bootstrap lock

Common options:
  --install-root <absolute-path>   (or LAZYKIMI_INSTALL_ROOT)
  --project <absolute-path>        (required)
  --json

Status options:
  --host <kimi|kimi-work>
  --route <kimi-plugin-manifest|kimi-work-skills-fallback>
  --observation-receipt <absolute-path>
  --host-build <current-kimi-build>
  --host-session <current-kimi-session>

Onboard/update options:
  --source <canonical-official-url>
  --confirm-revision <full-sha>

Full reference: node ${lifecycleCli} --help`);
}

export function run(args: string[]): number {
  if (args.length === 0 || args.includes('--help') || args.includes('-h')) {
    printHelp();
    return 0;
  }

  const command = args[0];
  if (!LIFECYCLE_COMMANDS.includes(command)) {
    console.error(`lazykimi lifecycle: unknown command '${command}'`);
    console.error(`Supported: ${LIFECYCLE_COMMANDS.join(', ')}`);
    return 1;
  }

  const cli = path.join(getPluginRoot(), 'scripts', 'lazykimi-lifecycle.js');
  if (!existsSync(cli)) {
    console.error(`lazykimi lifecycle: durable lifecycle CLI not found: ${cli}`);
    return 1;
  }

  const forwarded = [...args];
  if (!forwarded.includes('--install-root') && process.env.LAZYKIMI_INSTALL_ROOT) {
    forwarded.push('--install-root', process.env.LAZYKIMI_INSTALL_ROOT);
  }
  if (!forwarded.includes('--project') && !forwarded.includes('--install-root')) {
    // cli.js requires --project; default to the current directory for the
    // convenience of `lazykimi lifecycle status` run inside a project.
    forwarded.push('--project', process.cwd());
  }

  const result = spawnSync(process.execPath, [cli, ...forwarded], {
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
    console.error(`lazykimi lifecycle: failed to run ${cli}: ${result.error.message}`);
    return 1;
  }
  return result.status ?? 1;
}
