import { existsSync } from 'fs';
import path from 'path';
import { getPluginKimiCodeDir } from '../lib/paths';
import { readJson, isObject } from '../lib/json';
import { MCP_TOOL_SURFACE, EXPECTED_MCP_TOOLS } from '../lib/mcp-validation';

export function run(args: string[]): number {
  const asJson = args.includes('--json');
  if (args.includes('--help') || args.includes('-h')) {
    console.log(`Usage: lazykimi mcp [options]

Print MCP server declarations for Kimi Code CLI /mcp-config import.

Options:
  --help, -h   Show this help message
  --json       Output as JSON for /mcp-config import`);
    return 0;
  }

  const mcpPath = path.join(getPluginKimiCodeDir(), 'mcp.json');
  if (!existsSync(mcpPath)) {
    console.error('mcp.json not found in plugin package.');
    return 1;
  }

  let data: unknown;
  try {
    data = readJson(mcpPath);
  } catch (e) {
    console.error(`mcp.json is not valid JSON: ${e instanceof Error ? e.message : String(e)}`);
    return 1;
  }
  if (!isObject(data)) {
    console.error('mcp.json is not a valid object.');
    return 1;
  }
  const servers = data.mcpServers;
  if (!isObject(servers)) {
    console.error('mcp.json has no mcpServers object.');
    return 1;
  }

  const serverNames = Object.keys(servers);

  if (asJson) {
    console.log(JSON.stringify({ mcpServers: servers }, null, 2));
    return 0;
  }

  console.log('LazyKimi MCP Server Declarations');
  console.log('==================================\n');
  console.log(`Found ${serverNames.length} servers (${EXPECTED_MCP_TOOLS} tools total):\n`);
  for (const name of serverNames) {
    const server = servers[name];
    if (isObject(server)) {
      const cmd = typeof server.command === 'string' ? server.command : '?';
      const argsVal = Array.isArray(server.args) ? (server.args as string[]).join(' ') : '';
      const required = server.required === false ? 'false' : 'true';
      const tools = MCP_TOOL_SURFACE[name];
      console.log(`  ${name}`);
      console.log(`    command:  ${cmd} ${argsVal}`.trimEnd());
      console.log(`    required: ${required}`);
      if (tools) {
        console.log(`    tools:    ${tools.length} (${tools.join(', ')})`);
      }
      console.log('');
    }
  }
  console.log('Path resolution:');
  console.log('  The source .kimi-code/mcp.json uses __KIMI_PLUGIN_ROOT__');
  console.log('  placeholders. Kimi Code CLI does NOT interpolate env vars in');
  console.log('  project-level mcp.json (per');
  console.log('  https://www.kimi.com/code/docs/kimi-code-cli/customization/mcp.html),');
  console.log('  so the placeholder must be replaced with an absolute path.');
  console.log('');
  console.log('  - `lazykimi init` rewrites __KIMI_PLUGIN_ROOT__ to the absolute');
  console.log('    plugin root (resolved at install time) in the copied');
  console.log('    .kimi-code/mcp.json. This is the recommended route.');
  console.log('  - Users who clone the repo WITHOUT running `lazykimi init` must');
  console.log('    manually replace __KIMI_PLUGIN_ROOT__ in .kimi-code/mcp.json');
  console.log('    with the absolute path to the lazykimi-plugin directory.');
  console.log('');
  console.log('To register in Kimi Code CLI:');
  console.log('  1. Run `lazykimi init` in the target project (rewrites paths).');
  console.log('  2. Open the project in Kimi Code CLI and run `/mcp`.');
  console.log('  3. Confirm each lazykimi-* server connects.');
  console.log('\nFor JSON output: `lazykimi mcp --json`');
  return 0;
}
