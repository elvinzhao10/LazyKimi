#!/usr/bin/env node
import { run as runInit } from './commands/init';
import { run as runDoctor } from './commands/doctor';
import { run as runVerify } from './commands/verify';
import { run as runLoadCheck } from './commands/load-check';
import { run as runUninstall } from './commands/uninstall';
import { run as runMcp } from './commands/mcp';
import { run as runTooling } from './commands/tooling';
import { run as runSync } from './commands/sync';
import { run as runHandoff } from './commands/handoff';
import { run as runCompletionStatus } from './commands/completion-status';
import { run as runLifecycle } from './commands/lifecycle';

type CommandFn = (args: string[]) => number;

const commands: Record<string, CommandFn> = {
  init: runInit,
  doctor: runDoctor,
  verify: runVerify,
  'completion-status': runCompletionStatus,
  'load-check': runLoadCheck,
  uninstall: runUninstall,
  mcp: runMcp,
  tooling: runTooling,
  sync: runSync,
  handoff: runHandoff,
  lifecycle: runLifecycle,
};

const aliases: Record<string, string> = {
  i: 'init',
  d: 'doctor',
  v: 'verify',
  cs: 'completion-status',
  rm: 'uninstall',
};

function printUsage(): void {
  console.log(`LazyKimi CLI v1.3.3 -- Kimi-native evidence-led agent workflow harness

Usage: lazykimi <command> [options]

Commands:
  init              Install LazyKimi into the current project
  doctor            Check LazyKimi installation health
  verify            Run doctor + regression tests + evidence gates; --must-pass
  completion-status Run doctor + regression tests + evidence gates and report READY/NOT READY
  load-check        Report package readiness (skills/agents/hooks/mcp counts)
  uninstall         Remove LazyKimi from the current project
  sync              Update managed templates in an existing LazyKimi project
  handoff           Generate a Markdown handoff summary of active work and evidence
  mcp               Print MCP server declarations for /mcp-config import
  tooling           Query the receipt-owned tooling capability broker
  lifecycle         Durable onboard/update/status/offboard lifecycle

Aliases: i=init, d=doctor, v=verify, cs=completion-status, rm=uninstall

Run 'lazykimi <command> --help' for command-specific options.`);
}

function main(): void {
  const args = process.argv.slice(2);
  const cmdName = args[0] || '';
  const resolved = aliases[cmdName] || cmdName;

  if (!resolved || resolved === '--help' || resolved === '-h') {
    printUsage();
    process.exit(0);
  }

  const cmd = commands[resolved];
  if (!cmd) {
    console.error(`lazykimi: Unknown command '${cmdName}'`);
    console.error("Run 'lazykimi --help' for usage.");
    process.exit(1);
  }

  const cmdArgs = args.slice(1);
  const exitCode = cmd(cmdArgs);
  process.exit(exitCode);
}

main();
