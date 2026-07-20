import { existsSync, readdirSync, writeFileSync, mkdirSync, statSync } from 'fs';
import path from 'path';
import { readJson, isObject } from '../lib/json';

const HANDOFF_PATH = path.join('.lazykimi', 'evidence', 'handoff.md');
const BOULDER_PATH = path.join('.lazykimi', 'state', 'boulder.json');
const ACTIVE_LOOP_PATH = path.join('.lazykimi', 'state', 'active-loop.json');
const EVIDENCE_DIR = path.join('.lazykimi', 'evidence');
const RECENT_EVIDENCE_LIMIT = 5;

interface WorkEntry {
  readonly work_id: string;
  readonly active_plan?: string;
  readonly plan_name?: string;
  readonly status?: string;
  readonly tasks_completed?: number;
  readonly tasks_remaining?: number;
  readonly started_at?: string;
}

interface BoulderState {
  readonly active_work_id: string | null;
  readonly works: Record<string, unknown>;
}

interface ActiveLoopState {
  readonly loop_id?: string;
  readonly objective?: string;
  readonly mode?: string;
  readonly status?: string;
  readonly turn_count?: number;
  readonly started_at?: string;
}

function readBoulder(target: string): BoulderState | null {
  const filePath = path.join(target, BOULDER_PATH);
  if (!existsSync(filePath)) return null;
  try {
    const data = readJson(filePath);
    if (!isObject(data)) return null;
    const works = data.works;
    return {
      active_work_id: typeof data.active_work_id === 'string' ? data.active_work_id : null,
      works: isObject(works) ? works : {},
    };
  } catch {
    return null;
  }
}

function readActiveLoop(target: string): ActiveLoopState | null {
  const filePath = path.join(target, ACTIVE_LOOP_PATH);
  if (!existsSync(filePath)) return null;
  try {
    const data = readJson(filePath);
    if (!isObject(data)) return null;
    return data as ActiveLoopState;
  } catch {
    return null;
  }
}

function asWorkEntry(value: unknown): WorkEntry | null {
  if (!isObject(value)) return null;
  const workId = value.work_id;
  if (typeof workId !== 'string') return null;
  return {
    work_id: workId,
    active_plan: typeof value.active_plan === 'string' ? value.active_plan : undefined,
    plan_name: typeof value.plan_name === 'string' ? value.plan_name : undefined,
    status: typeof value.status === 'string' ? value.status : undefined,
    tasks_completed: typeof value.tasks_completed === 'number' ? value.tasks_completed : undefined,
    tasks_remaining: typeof value.tasks_remaining === 'number' ? value.tasks_remaining : undefined,
    started_at: typeof value.started_at === 'string' ? value.started_at : undefined,
  };
}

function getActiveWork(boulder: BoulderState | null, activeLoop: ActiveLoopState | null): WorkEntry | null {
  if (!boulder) return null;
  let workId: string | null | undefined = boulder.active_work_id;
  if (!workId && activeLoop) {
    workId = activeLoop.loop_id;
  }
  if (!workId) return null;
  return asWorkEntry(boulder.works[workId]);
}

function recentEvidence(target: string): string[] {
  const dir = path.join(target, EVIDENCE_DIR);
  if (!existsSync(dir)) return [];
  const files: Array<{ readonly mtime: number; readonly name: string }> = [];
  for (const name of readdirSync(dir)) {
    if (!name.endsWith('.md') || name === 'handoff.md') continue;
    const filePath = path.join(dir, name);
    try {
      const st = statSync(filePath);
      files.push({ mtime: st.mtimeMs, name });
    } catch {
      continue;
    }
  }
  files.sort((a, b) => b.mtime - a.mtime);
  return files.slice(0, RECENT_EVIDENCE_LIMIT).map(f => f.name);
}

function generateHandoff(target: string): string {
  const boulder = readBoulder(target);
  const activeLoop = readActiveLoop(target);
  const activeWork = getActiveWork(boulder, activeLoop);

  const lines: string[] = [
    '# LazyKimi Handoff',
    '',
    `Generated: ${new Date().toISOString()}`,
    '',
    '## Active Work',
  ];

  if (activeWork) {
    lines.push(`- work_id: ${activeWork.work_id}`);
    if (activeWork.plan_name) lines.push(`- plan_name: ${activeWork.plan_name}`);
    if (activeWork.active_plan) lines.push(`- plan_path: ${activeWork.active_plan}`);
    if (activeWork.status) lines.push(`- status: ${activeWork.status}`);
    if (typeof activeWork.tasks_completed === 'number') lines.push(`- tasks_completed: ${activeWork.tasks_completed}`);
    if (typeof activeWork.tasks_remaining === 'number') lines.push(`- tasks_remaining: ${activeWork.tasks_remaining}`);
    if (activeWork.started_at) lines.push(`- started_at: ${activeWork.started_at}`);
  } else {
    lines.push('- (none)');
  }

  lines.push('', '## Active Loop');
  if (activeLoop) {
    for (const key of ['loop_id', 'objective', 'mode', 'status', 'turn_count', 'started_at'] as const) {
      const value = activeLoop[key];
      if (value !== undefined) lines.push(`- ${key}: ${value}`);
    }
  } else {
    lines.push('- (none)');
  }

  lines.push('', '## Recent Evidence');
  const evidence = recentEvidence(target);
  if (evidence.length > 0) {
    for (const name of evidence) lines.push(`- ${name}`);
  } else {
    lines.push('- (none)');
  }

  lines.push('', '## Next Steps');
  if (activeWork && activeWork.status && activeWork.status !== 'completed') {
    lines.push('- Continue the active work plan.');
    if ((activeWork.tasks_remaining ?? 0) > 0) {
      lines.push(`- Remaining tasks: ${activeWork.tasks_remaining}.`);
    }
    if (activeLoop?.objective) {
      lines.push(`- Active objective: ${activeLoop.objective}`);
    }
  } else if (activeLoop?.objective && activeLoop.status !== 'completed') {
    lines.push(`- Resume loop objective: ${activeLoop.objective}`);
  } else {
    lines.push('- (none)');
  }

  lines.push('');
  return lines.join('\n');
}

interface HandoffOptions {
  readonly stdout: boolean;
  readonly target: string;
}

function printHelp(): void {
  console.log(`Usage: lazykimi handoff [options]

Generate a Markdown handoff summary from the current LazyKimi state and
evidence files. Writes to .lazykimi/evidence/handoff.md by default.

Options:
  --help, -h        Show this help message
  --stdout          Print the handoff to stdout instead of writing to file
  --target <path>   Target directory (default: current directory)`);
}

function parseArgs(args: string[]): HandoffOptions | null {
  let stdout = false;
  let target = process.cwd();
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === '--help' || a === '-h') { printHelp(); return null; }
    else if (a === '--stdout') stdout = true;
    else if (a === '--target' && i + 1 < args.length) target = args[++i];
  }
  return { stdout, target };
}

export function run(args: string[]): number {
  const opts = parseArgs(args);
  if (opts === null) return 0;

  const markdown = generateHandoff(opts.target);

  if (opts.stdout) {
    console.log(markdown);
    return 0;
  }

  const outPath = path.join(opts.target, HANDOFF_PATH);
  mkdirSync(path.dirname(outPath), { recursive: true });
  writeFileSync(outPath, markdown, 'utf-8');
  console.log(`Handoff written to ${HANDOFF_PATH}`);
  return 0;
}
