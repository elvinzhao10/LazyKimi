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

// v1.3.4 family tool surface: the exact tool-name sets of the LazyZCode v1.3.4
// servers, split 9/7/4/5/5/2 across the six declared servers (32 tools total).
// run-ledger/verification/status-dashboard are bash server.sh JSON-RPC loops
// delegating to scripts/state/*; context-graph/code-intel/docs are python
// servers behind profile-gated launchers.
export const MCP_TOOL_SURFACE: Readonly<Record<string, readonly string[]>> = {
  'lazykimi-run-ledger': [
    'create_run', 'list_runs', 'latest_run', 'read_state', 'summarize_run',
    'append_event', 'update_task', 'create_checkpoint', 'recover_run',
  ],
  'lazykimi-verification': [
    'discover_checks', 'run_check', 'record_gate_result', 'record_criterion_result',
    'list_gate_results', 'create_repair_task', 'summarize_verification',
  ],
  'lazykimi-status-dashboard': [
    'show_run_status', 'show_task_graph', 'show_verification_matrix', 'show_pending_approvals',
  ],
  'lazykimi-context-graph': [
    'blast_radius', 'file_deps', 'symbol_search', 'symbol_refs', 'repo_overview',
  ],
  'lazykimi-code-intel': [
    'diagnostics', 'typecheck', 'find_references', 'goto_definition', 'symbols',
  ],
  'lazykimi-docs': [
    'get_library_docs', 'list_supported_registries',
  ],
};

export const EXPECTED_MCP_TOOLS: number = Object.values(MCP_TOOL_SURFACE)
  .reduce((sum, tools) => sum + tools.length, 0);

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
