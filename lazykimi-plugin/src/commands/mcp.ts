import { existsSync } from 'fs';
import path from 'path';
import { getPluginKimiCodeDir } from '../lib/paths';
import { readJson, isObject } from '../lib/json';

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
  console.log(`Found ${serverNames.length} servers:\n`);
  for (const name of serverNames) {
    const server = servers[name];
    if (isObject(server)) {
      const cmd = typeof server.command === 'string' ? server.command : '?';
      const argsVal = Array.isArray(server.args) ? (server.args as string[]).join(' ') : '';
      const required = server.required === false ? 'false' : 'true';
      console.log(`  ${name}`);
      console.log(`    command:  ${cmd} ${argsVal}`.trimEnd());
      console.log(`    required: ${required}`);
      console.log('');
    }
  }
  console.log('To register in Kimi Code CLI:');
  console.log('  1. Run `kimi /mcp-config`');
  console.log('  2. Import this configuration, OR add each server manually.');
  console.log('  3. Set KIMI_PLUGIN_ROOT to the lazykimi-plugin directory.');
  console.log('\nFor JSON output: `lazykimi mcp --json`');
  return 0;
}
