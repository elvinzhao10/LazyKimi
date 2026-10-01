#!/usr/bin/env node
'use strict';

// The project MCP configuration binds an absolute root at init time. Plugin
// manifest stdio has no project context; never interpret its managed cwd as one.
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const servers = new Set(['run-ledger', 'verification', 'status-dashboard', 'context-graph', 'code-intel', 'docs']);
const modes = new Set(['direct', 'assisted', 'planned', 'orchestrated', 'long-horizon']);

function main(args) {
  const [server, projectFlag, project, modeFlag, mode = 'orchestrated'] = args;
  const plugin = path.resolve(__dirname, '..');
  if (!servers.has(server) || projectFlag !== '--project' || !project || !path.isAbsolute(project)
    || (modeFlag !== undefined && modeFlag !== '--mode') || !modes.has(mode) || args.length > 5) {
    process.stderr.write('LazyKimi MCP: explicit project binding required; use lazykimi init --target <absolute-project> and the project MCP route. Managed plugin cwd is not a project.\n');
    return 2;
  }
  try {
    const stat = fs.lstatSync(project);
    const real = fs.realpathSync(project);
    if (!stat.isDirectory() || stat.isSymbolicLink() || real === plugin || real.startsWith(`${plugin}${path.sep}`)) {
      process.stderr.write('LazyKimi MCP: unsafe project binding\n');
      return 2;
    }
    const result = spawnSync('bash', [path.join(plugin, 'mcp', server, 'server.sh')], {
      cwd: real, env: { ...process.env, CWD: real, LAZYKIMI_MCP_MODE: mode }, stdio: 'inherit',
    });
    if (result.error) { process.stderr.write(`${result.error.message}\n`); return 2; }
    return result.status ?? 2;
  } catch (error) {
    process.stderr.write(`LazyKimi MCP: unavailable project binding: ${error.message}\n`);
    return 2;
  }
}
if (require.main === module) process.exitCode = main(process.argv.slice(2));
module.exports = { main };
