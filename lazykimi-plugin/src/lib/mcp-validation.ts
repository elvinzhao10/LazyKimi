import { existsSync } from 'fs';
import { readJson, isObject } from './json';

export const REQUIRED_MCP_SERVERS: readonly string[] = [
  'lazykimi-run-ledger',
  'lazykimi-verification',
  'lazykimi-status-dashboard',
  'lazykimi-context-graph',
  'lazykimi-code-intel',
  'lazykimi-docs',
];

export const OPTIONAL_CAPABILITY_NAMES: readonly string[] = [
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

export const OPTIONAL_MCP_SERVERS: readonly string[] = OPTIONAL_CAPABILITY_NAMES.map(serverNameForCapability);

const REQUIRED_MCP_SET = new Set(REQUIRED_MCP_SERVERS);
const OPTIONAL_MCP_SET = new Set(OPTIONAL_MCP_SERVERS);

export interface McpValidationResult {
  readonly valid: boolean;
  readonly count: number;
  readonly required: number;
  readonly optional: number;
  readonly missing: readonly string[];
  readonly unknown: readonly string[];
}

export function validateMcpServers(mcpPath: string): McpValidationResult {
  if (!existsSync(mcpPath)) {
    return {
      valid: false,
      count: 0,
      required: REQUIRED_MCP_SERVERS.length,
      optional: 0,
      missing: REQUIRED_MCP_SERVERS.slice(),
      unknown: [],
    };
  }

  try {
    const data = readJson(mcpPath);
    if (!isObject(data)) {
      return {
        valid: false,
        count: 0,
        required: REQUIRED_MCP_SERVERS.length,
        optional: 0,
        missing: REQUIRED_MCP_SERVERS.slice(),
        unknown: [],
      };
    }

    const servers = data.mcpServers;
    if (!isObject(servers)) {
      return {
        valid: false,
        count: 0,
        required: REQUIRED_MCP_SERVERS.length,
        optional: 0,
        missing: REQUIRED_MCP_SERVERS.slice(),
        unknown: [],
      };
    }

    const names = Object.keys(servers);
    const missing = REQUIRED_MCP_SERVERS.filter(name => !names.includes(name));
    const unknown = names.filter(name => !REQUIRED_MCP_SET.has(name) && !OPTIONAL_MCP_SET.has(name));
    const optional = names.filter(name => OPTIONAL_MCP_SET.has(name)).length;

    return {
      valid: missing.length === 0 && unknown.length === 0,
      count: names.length,
      required: REQUIRED_MCP_SERVERS.length,
      optional,
      missing,
      unknown,
    };
  } catch {
    return {
      valid: false,
      count: 0,
      required: REQUIRED_MCP_SERVERS.length,
      optional: 0,
      missing: REQUIRED_MCP_SERVERS.slice(),
      unknown: [],
    };
  }
}
