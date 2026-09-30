import { existsSync, readdirSync, readFileSync } from 'fs';
import path from 'path';
import { spawnSync } from 'child_process';
import { runDoctor, type DoctorResult } from '../commands/doctor';
import { isPluginSourceRoot } from './paths';

export const EVIDENCE_GATES = [
  'plan-reread',
  'automated-verification',
  'manual-qa',
  'adversarial-qa',
  'cleanup',
] as const;

export const EVIDENCE_FILES: Record<string, string> = {
  'plan-reread': '.lazykimi/evidence/plan-reread.md',
  'automated-verification': '.lazykimi/evidence/test-runs.md',
  'manual-qa': '.lazykimi/evidence/manual-qa.md',
  'adversarial-qa': '.lazykimi/evidence/adversarial-qa.md',
  'cleanup': '.lazykimi/evidence/reviewer.md',
};

export interface GateResult {
  readonly gate: string;
  readonly status: 'PASS' | 'FAIL';
  readonly detail: string;
}

export interface TestResult {
  readonly ran: boolean;
  readonly passed: boolean;
  readonly detail: string;
}

export interface CompletionResult {
  readonly doctor: DoctorResult;
  readonly tests: TestResult;
  readonly gates: GateResult[];
  readonly ready: boolean;
}

export function resolveEvidenceProjectRoot(target: string): string {
  if (isPluginSourceRoot(target)) {
    return path.join(target, '..');
  }
  return target;
}

function isHeading(line: string): boolean {
  return /^#+\s/.test(line);
}

function isPlaceholder(line: string): boolean {
  return /^\(?\s*none\s*yet\s*\)?$/i.test(line);
}

export function hasEvidenceContent(filePath: string): boolean {
  const content = readFileSync(filePath, 'utf-8');
  for (const raw of content.split(/\r?\n/)) {
    const line = raw.trim();
    if (line.length === 0) continue;
    // A bullet is treated as concrete evidence.
    if (/^[-*]\s+/.test(line)) return true;
    if (isHeading(line)) continue;
    if (isPlaceholder(line)) continue;
    // Any other non-empty, non-heading, non-placeholder line counts.
    return true;
  }
  return false;
}

export function checkEvidenceGates(target: string): GateResult[] {
  const results: GateResult[] = [];
  const projectRoot = resolveEvidenceProjectRoot(target);
  for (const gate of EVIDENCE_GATES) {
    const file = EVIDENCE_FILES[gate];
    const fullPath = path.join(projectRoot, file);
    if (!existsSync(fullPath)) {
      results.push({ gate, status: 'FAIL', detail: `${file} not found` });
      continue;
    }
    try {
      const hasContent = hasEvidenceContent(fullPath);
      results.push({
        gate,
        status: hasContent ? 'PASS' : 'FAIL',
        detail: hasContent ? file : `${file} contains only placeholder content`,
      });
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      results.push({ gate, status: 'FAIL', detail: `${file} could not be read: ${message}` });
    }
  }
  return results;
}

export function runRegressionTests(target: string): TestResult {
  const testsDir = path.join(target, 'tests');
  if (!existsSync(testsDir)) {
    return { ran: false, passed: true, detail: 'no tests/ directory (skipped)' };
  }
  const scripts = readdirSync(testsDir).filter((f: string) => f.endsWith('.sh'));
  if (scripts.length === 0) {
    return { ran: false, passed: true, detail: 'no .sh test scripts (skipped)' };
  }
  let passed = 0;
  let failed = 0;
  let skipped = 0;
  for (const script of scripts) {
    const scriptPath = path.join(testsDir, script);
    // Family parity checks take explicit roots and never infer a sibling
    // checkout: run them only when the reference root is provided via
    // LAZYKIMI_LAZYZCODE_ROOT; otherwise skip with a notice.
    const args: string[] = [];
    if (script.includes('contract-parity')) {
      const lazyzcodeRoot = process.env.LAZYKIMI_LAZYZCODE_ROOT || '';
      if (!lazyzcodeRoot) {
        skipped++;
        continue;
      }
      args.push('--lazyzcode-root', lazyzcodeRoot, '--lazykimi-root', path.resolve(target, '..'));
    }
    const result = spawnSync('bash', [scriptPath, ...args], { encoding: 'utf-8', cwd: target, stdio: 'pipe' });
    if (result.status === 0) passed++;
    else failed++;
  }
  return {
    ran: true,
    passed: failed === 0,
    detail: `${passed} passed, ${failed} failed, ${skipped} skipped (${scripts.length} total)`,
  };
}

function hasActiveWork(target: string): boolean | 'unknown' {
  const projectRoot = resolveEvidenceProjectRoot(target);
  const boulderPath = path.join(projectRoot, '.lazykimi', 'state', 'boulder.json');
  if (!existsSync(boulderPath)) {
    return false;
  }
  try {
    const raw = readFileSync(boulderPath, 'utf-8').trim();
    if (raw.length === 0) {
      return false;
    }
    const boulder = JSON.parse(raw) as { active_work_id?: unknown };
    return boulder.active_work_id !== undefined && boulder.active_work_id !== null;
  } catch {
    return 'unknown';
  }
}

export function runCompletionChecks(target: string): CompletionResult {
  const doctor = runDoctor(target);
  const tests = runRegressionTests(target);
  const activeWork = hasActiveWork(target);
  const gates: GateResult[] =
    activeWork === false
      ? EVIDENCE_GATES.map(gate => ({ gate, status: 'PASS', detail: 'no active work' }))
      : checkEvidenceGates(target);
  const ready = doctor.fail === 0 && tests.passed && gates.every(g => g.status === 'PASS');
  return { doctor, tests, gates, ready };
}
