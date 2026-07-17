import { existsSync, readdirSync } from 'fs';
import path from 'path';
import { getPluginKimiCodeDir, getPluginAgentsDir, getPluginHooksDir, getPluginRoot } from '../lib/paths';
import { readJson, isObject } from '../lib/json';

const PLUGIN_VERSION = '0.1.0';
const EXPECTED_SKILLS = 17;
const EXPECTED_AGENTS = 11;
const EXPECTED_HOOKS = 16;
const EXPECTED_MCP = 6;

function countPluginSkills(): number {
  const skillsDir = path.join(getPluginKimiCodeDir(), 'skills');
  if (!existsSync(skillsDir)) return 0;
  const entries = readdirSync(skillsDir, { withFileTypes: true });
  let count = 0;
  for (const e of entries) {
    if (e.isDirectory() && e.name.startsWith('lazy-')) {
      if (existsSync(path.join(skillsDir, e.name, 'SKILL.md'))) count++;
    }
  }
  return count;
}

function countPluginAgents(): number {
  const agentsDir = getPluginAgentsDir();
  if (!existsSync(agentsDir)) return 0;
  return readdirSync(agentsDir).filter((f: string) => f.startsWith('lazykimi-') && f.endsWith('.md')).length;
}

function countPluginHooks(): number {
  const hooksDir = getPluginHooksDir();
  if (!existsSync(hooksDir)) return 0;
  return readdirSync(hooksDir).filter((f: string) => f.endsWith('.sh')).length;
}

function countPluginMcp(): number {
  const mcpPath = path.join(getPluginKimiCodeDir(), 'mcp.json');
  if (!existsSync(mcpPath)) return 0;
  try {
    const data = readJson(mcpPath);
    if (!isObject(data)) return 0;
    const servers = data.mcpServers;
    if (!isObject(servers)) return 0;
    return Object.keys(servers).length;
  } catch {
    return 0;
  }
}

export function run(args: string[]): number {
  if (args.includes('--help') || args.includes('-h')) {
    console.log(`Usage: lazykimi load-check

Report package readiness: skills, agents, hooks, and MCP server counts.
This checks the plugin's own bundled assets, NOT a host connection.

Options:
  --help, -h   Show this help message`);
    return 0;
  }

  const skills = countPluginSkills();
  const agents = countPluginAgents();
  const hooks = countPluginHooks();
  const mcp = countPluginMcp();
  const allReady =
    skills === EXPECTED_SKILLS &&
    agents === EXPECTED_AGENTS &&
    hooks === EXPECTED_HOOKS &&
    mcp === EXPECTED_MCP;

  console.log(`LazyKimi load-check v${PLUGIN_VERSION}`);
  console.log(`Plugin root: ${getPluginRoot()}\n`);
  console.log(`  ${skills}/${EXPECTED_SKILLS} skills`);
  console.log(`  ${agents}/${EXPECTED_AGENTS} agents`);
  console.log(`  ${hooks}/${EXPECTED_HOOKS} hooks`);
  console.log(`  ${mcp}/${EXPECTED_MCP} MCP servers`);
  console.log('');
  if (allReady) {
    console.log('Status: PACKAGE READY');
    console.log('Note: package readiness is NOT host connection.');
    console.log('      Run `lazykimi doctor` in a target project after `lazykimi init`.');
  } else {
    console.log('Status: MISSING ASSETS');
    if (skills < EXPECTED_SKILLS) console.log(`  missing ${EXPECTED_SKILLS - skills} skill(s)`);
    if (agents < EXPECTED_AGENTS) console.log(`  missing ${EXPECTED_AGENTS - agents} agent(s)`);
    if (hooks < EXPECTED_HOOKS) console.log(`  missing ${EXPECTED_HOOKS - hooks} hook(s)`);
    if (mcp < EXPECTED_MCP) console.log(`  missing ${EXPECTED_MCP - mcp} MCP server(s)`);
  }
  return allReady ? 0 : 1;
}
