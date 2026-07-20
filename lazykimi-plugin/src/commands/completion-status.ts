import { runCompletionChecks } from '../lib/completion';
import { detectTargetRoot } from '../lib/paths';

const PLUGIN_VERSION = '0.2.0';

function pad(text: string, width: number): string {
  return text.length > width ? text.slice(0, width - 1) + '…' : text.padEnd(width);
}

export function run(args: string[]): number {
  const json = args.includes('--json');
  if (args.includes('--help') || args.includes('-h')) {
    console.log(`Usage: lazykimi completion-status [options]

Check completion readiness: doctor + regression tests + evidence gates.

Options:
  --help, -h   Show this help message
  --json       Output results as JSON`);
    return 0;
  }

  const target = detectTargetRoot();
  const result = runCompletionChecks(target);

  if (json) {
    console.log(JSON.stringify({
      ready: result.ready,
      doctor: {
        pass: result.doctor.pass,
        warn: result.doctor.warn,
        fail: result.doctor.fail,
        checks: result.doctor.checks,
      },
      tests: result.tests,
      gates: result.gates,
    }, null, 2));
    return result.ready ? 0 : 1;
  }

  console.log(`LazyKimi Completion Status v${PLUGIN_VERSION}`);
  console.log(`Target: ${target}\n`);

  const gateNameWidth = Math.max(...result.gates.map(g => g.gate.length), 4);
  const detailWidth = Math.max(...result.gates.map(g => g.detail.length), 6);
  console.log(`${pad('Gate', gateNameWidth)}  Status  ${pad('Detail', detailWidth)}`);
  console.log(`${''.padEnd(gateNameWidth, '-')}  ------  ${''.padEnd(detailWidth, '-')}`);
  for (const g of result.gates) {
    console.log(`${pad(g.gate, gateNameWidth)}  ${g.status.padEnd(6)} ${pad(g.detail, detailWidth)}`);
  }

  console.log(`\nDoctor: ${result.doctor.fail === 0 ? 'PASS' : 'FAIL'} (${result.doctor.pass} PASS, ${result.doctor.warn} WARN, ${result.doctor.fail} FAIL)`);
  console.log(`Tests:  ${result.tests.passed ? 'PASS' : 'FAIL'} (${result.tests.detail})`);
  console.log(`\nOverall: ${result.ready ? 'READY' : 'NOT READY'}`);

  return result.ready ? 0 : 1;
}
