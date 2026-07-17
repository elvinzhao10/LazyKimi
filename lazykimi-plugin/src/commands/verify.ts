import { existsSync, readdirSync } from 'fs';
import path from 'path';
import { spawnSync } from 'child_process';
import { runDoctor } from './doctor';

const PLUGIN_VERSION = '0.1.0';

const EVIDENCE_GATES = [
  'plan-reread',
  'automated-verification',
  'manual-qa',
  'adversarial-qa',
  'cleanup',
] as const;

const EVIDENCE_FILES: Record<string, string> = {
  'plan-reread': '.lazykimi/evidence/plan-reread.md',
  'automated-verification': '.lazykimi/evidence/test-runs.md',
  'manual-qa': '.lazykimi/evidence/manual-qa.md',
  'adversarial-qa': '.lazykimi/evidence/oracle-review.md',
  'cleanup': '.lazykimi/evidence/reviewer.md',
};

interface GateResult {
  readonly gate: string;
  readonly status: 'PASS' | 'FAIL';
  readonly detail: string;
}

interface TestResult {
  readonly ran: boolean;
  readonly passed: boolean;
  readonly detail: string;
}

function checkEvidenceGates(target: string): GateResult[] {
  const results: GateResult[] = [];
  for (const gate of EVIDENCE_GATES) {
    const file = EVIDENCE_FILES[gate];
    const fullPath = path.join(target, file);
    const exists = existsSync(fullPath);
    results.push({
      gate,
      status: exists ? 'PASS' : 'FAIL',
      detail: exists ? file : `${file} not found`,
    });
  }
  return results;
}

function runRegressionTests(target: string): TestResult {
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
  for (const script of scripts) {
    const scriptPath = path.join(testsDir, script);
    const result = spawnSync('bash', [scriptPath], { encoding: 'utf-8', cwd: target, stdio: 'pipe' });
    if (result.status === 0) passed++;
    else failed++;
  }
  return {
    ran: true,
    passed: failed === 0,
    detail: `${passed} passed, ${failed} failed (${scripts.length} total)`,
  };
}

export function run(args: string[]): number {
  const mustPass = args.includes('--must-pass');
  if (args.includes('--help') || args.includes('-h')) {
    console.log(`Usage: lazykimi verify [options]

Run doctor checks, regression tests, and evidence gate verification.

Options:
  --help, -h   Show this help message
  --must-pass  Exit 1 if any gate fails (non-blocking otherwise)`);
    return 0;
  }
  const target = process.cwd();

  // 1. Doctor
  console.log('=== Doctor ===');
  const doctorResult = runDoctor(target);
  const maxLabel = Math.max(...doctorResult.checks.map(c => c.label.length));
  for (const c of doctorResult.checks) {
    const label = c.label.padEnd(maxLabel + 2);
    console.log(`  [${c.status}] ${label} ${c.detail ?? ''}`);
  }
  console.log(`  Results: ${doctorResult.pass} PASS, ${doctorResult.warn} WARN, ${doctorResult.fail} FAIL\n`);

  // 2. Regression tests
  console.log('=== Regression Tests ===');
  const testResult = runRegressionTests(target);
  console.log(`  ${testResult.ran ? 'RAN' : 'SKIP'} ${testResult.detail}\n`);

  // 3. Evidence gates
  console.log('=== Evidence Gates ===');
  const gates = checkEvidenceGates(target);
  for (const g of gates) {
    console.log(`  [${g.status}] ${g.gate.padEnd(22)} ${g.detail}`);
  }
  const gatesFailed = gates.filter(g => g.status === 'FAIL').length;
  console.log(`\n  Gates: ${gates.length - gatesFailed}/${gates.length} passed\n`);

  // 4. Summary
  const allPass = doctorResult.fail === 0 && testResult.passed && gatesFailed === 0;
  console.log('=== Summary ===');
  console.log(`  Doctor: ${doctorResult.fail === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`  Tests:  ${testResult.passed ? 'PASS' : 'FAIL'}`);
  console.log(`  Gates:  ${gatesFailed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`  Overall: ${allPass ? 'READY' : 'NOT READY'}`);
  console.log(`  (lazykimi verify v${PLUGIN_VERSION})`);

  if (mustPass && !allPass) return 1;
  return 0;
}
