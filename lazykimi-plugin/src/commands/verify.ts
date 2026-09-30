import { runCompletionChecks } from '../lib/completion';
import { detectTargetRoot } from '../lib/paths';

const PLUGIN_VERSION = '1.3.3';

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
  const target = detectTargetRoot();
  const result = runCompletionChecks(target);

  // 1. Doctor
  console.log('=== Doctor ===');
  const maxLabel = Math.max(...result.doctor.checks.map(c => c.label.length));
  for (const c of result.doctor.checks) {
    const label = c.label.padEnd(maxLabel + 2);
    console.log(`  [${c.status}] ${label} ${c.detail ?? ''}`);
  }
  console.log(`  Results: ${result.doctor.pass} PASS, ${result.doctor.warn} WARN, ${result.doctor.fail} FAIL\n`);

  // 2. Regression tests
  console.log('=== Regression Tests ===');
  console.log(`  ${result.tests.ran ? 'RAN' : 'SKIP'} ${result.tests.detail}\n`);

  // 3. Evidence gates
  console.log('=== Evidence Gates ===');
  for (const g of result.gates) {
    console.log(`  [${g.status}] ${g.gate.padEnd(22)} ${g.detail}`);
  }
  const gatesFailed = result.gates.filter(g => g.status === 'FAIL').length;
  console.log(`\n  Gates: ${result.gates.length - gatesFailed}/${result.gates.length} passed\n`);

  // 4. Summary
  console.log('=== Summary ===');
  console.log(`  Doctor: ${result.doctor.fail === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`  Tests:  ${result.tests.passed ? 'PASS' : 'FAIL'}`);
  console.log(`  Gates:  ${gatesFailed === 0 ? 'PASS' : 'FAIL'}`);
  console.log(`  Overall: ${result.ready ? 'READY' : 'NOT READY'}`);
  console.log(`  (lazykimi verify v${PLUGIN_VERSION})`);

  if (mustPass && !result.ready) return 1;
  return 0;
}
