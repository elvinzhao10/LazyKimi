from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from lazykimi_process_lifecycle import (CleanupStatus, InspectionAvailable, OwnershipTracker, ProcessRecord, SignalResult, cleanup_owned_processes)

ROOT = ProcessRecord(4100, 1, 4100, 'S', 'root-start')
CHILD = ProcessRecord(4101, 4100, 4100, 'S', 'child-start')

def test_foreign_pid_reuse_cannot_extend_owned_ancestry() -> None:
    tracker = OwnershipTracker.establish(ROOT, InspectionAvailable((ROOT, CHILD)))
    foreign = ProcessRecord(4101, 1, 6100, 'S', 'replacement-start')
    other = ProcessRecord(4102, 4101, 6100, 'S', 'foreign-child')
    current = InspectionAvailable((foreign, other))
    tracker = tracker.observe(current)
    assert 4102 not in {record.pid for record in tracker.tracked}
    signals: list[int] = []
    def signaler(group: int, _sig: int) -> SignalResult:
        signals.append(group)
        return SignalResult.sent()
    receipt = cleanup_owned_processes(tracker, lambda: current, signaler)
    assert receipt.status is CleanupStatus.VERIFIED_ABSENT
    assert signals == []

def test_matched_parent_proves_new_child_but_unexplained_reuse_stays_refused() -> None:
    tracker = OwnershipTracker.establish(ROOT, InspectionAvailable((ROOT, CHILD)))
    fresh = ProcessRecord(4101, 4100, 4100, 'S', 'fresh-child')
    renewed = tracker.observe(InspectionAvailable((ROOT, fresh)))
    assert next(record for record in renewed.tracked if record.pid == 4101).started == 'fresh-child'
    unrelated = ProcessRecord(4101, 1, 4100, 'S', 'unrelated')
    receipt = cleanup_owned_processes(tracker, lambda: InspectionAvailable((unrelated,)), lambda group, sig: SignalResult.sent())
    assert receipt.status is CleanupStatus.IDENTITY_CHANGED

def test_refused_signal_does_not_hide_an_observed_exit() -> None:
    tracker = OwnershipTracker.establish(ROOT, InspectionAvailable((ROOT, CHILD)))
    samples = iter((InspectionAvailable((CHILD,)), InspectionAvailable((CHILD,)), InspectionAvailable(())))
    receipt = cleanup_owned_processes(tracker, lambda: next(samples), lambda group, sig: SignalResult.refused('exiting'))
    assert receipt.status is CleanupStatus.VERIFIED_ABSENT

def test_refused_signal_with_survivor_stays_refused() -> None:
    tracker = OwnershipTracker.establish(ROOT, InspectionAvailable((ROOT, CHILD)))
    receipt = cleanup_owned_processes(tracker, lambda: InspectionAvailable((CHILD,)), lambda group, sig: SignalResult.refused('eperm'))
    assert receipt.status is CleanupStatus.SIGNAL_REFUSED
