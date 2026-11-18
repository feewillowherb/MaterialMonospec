## 1. Baseline and design checks

- [x] 1.1 Read applicable repository instructions and traits; reconcile HEAD and existing uncommitted research tests; use Mode A and the change-named branch before changing product code, without committing or pushing
- [x] 1.2 Enumerate create, plate rewrite, LPR attachment, Urban anomaly, status strategy and departure call sites; identify all reads of live cycle state
- [x] 1.3 Verify versioned ExtraProperties serialization, SQLite recovery scanning and restart readback using isolated storage; revise design if persistent recovery cannot be implemented reliably
- [x] 1.4 Verify sealed-cycle finalization can be idempotent without requeueing Synced records; preserve existing Urban stable-upload behavior

## 2. Cycle isolation and creation

- [x] 2.1 Add Guid cycle identity and type-owned lifecycle/creation state; create a new identity only at the established cycle boundary
- [x] 2.2 Carry named cycle snapshots through stable work, record creation, capture association, rewrite and mode-specific side effects; remove old-work dependence on the next cycle's live plate or RecordId
- [x] 2.3 Coordinate per-cycle creation, handle end-before-create and end-during-commit, persist CycleId and avoid uncertain-commit blind inserts
- [x] 2.4 Guard current-state writeback and cache release by cycle ownership; preserve same-cycle late plate selection, existing departure thresholds, sound isolation and single-callback enqueue protection

## 3. Finalization recovery

- [x] 3.1 Separate cycle release from fixed-record finalization; handle creation completing after departure without blocking the next vehicle
- [x] 3.2 Add type-owned versioned recovery and anomaly metadata with fixed CycleId, RecordId and sealed context; persist initial recoverable state with record creation
- [x] 3.3 Implement bounded background recovery with the specified delays, persisted attempt reservation, restart continuation, exhaustion and idempotent finalization; do not register pure logic in DI or use the weighing Merge queue
- [x] 3.4 Handle diagnostic persistence/database outages without hot loops or false success; log retained recovery responsibility
- [x] 3.5 Preserve no-photo/no-plate handling and attachment upload failure Pending behavior; do not modify server contracts or attachment failure policy

## 4. Regression verification

- [x] 4.1 Convert or complement existing cross-cycle characterization tests with deterministic barriers before capture completion, insert and commit; preserve original repro evidence
- [x] 4.2 Test concurrent same-cycle creates, sequential same-plate cycles, same-cycle late plate updates and old-cycle side effects during the next cycle
- [x] 4.3 Inject insert/finalization/metadata failures; prove the next cycle still creates its own record and old recovery cannot clear its state
- [x] 4.4 Test retry exhaustion, process restart with remaining attempts, interrupted successful side effects and no duplicate/requeued synced records
- [x] 4.5 Test no-photo/no-plate sync and attachment failure remaining Pending; run relevant existing weighing, sound and Urban regression suites, recording exact commands/results
- [x] 4.6 Run openspec validate fix-weighing-cycle-isolation --strict and applicable implementation checks

## 5. Target environment acceptance (ICD L3)

- [ ] 5.1 Record baseline/configuration and runtime evidence for consecutive vehicles, normal departure, same-cycle late plate and sound offline behavior
- [ ] 5.2 Verify declared cross-cycle and finalization-failure behaviors with safe controlled inputs, including recovery across restart, with logs and record identities
- [ ] 5.3 Report acceptance independently of completed tasks; leave unavailable environment checks incomplete and do not claim L3 from unit tests alone
