## 1. Orchestrator scheduling

- [x] 1.1 Before changing MaterialClient code, use the change-named branch under Mode A; do not commit or push without explicit authorization
- [x] 1.2 Add a local per-callback flag; set it after the transition path calls EnqueueAsyncOperation for OnWeightStabilizedAsync
- [x] 1.3 Add the flag check to backup, preserving other conditions; do not change stream deduplication, queue concurrency or capture behavior, or add cross-callback state

## 2. Deterministic regression tests

- [x] 2.1 Rename SingleStabilize_Reproduces_DoubleInsert_FromStatusAndBackupEnqueue as a regression; invoke the handler once from WaitingForStability with stable weight and null recordId
- [x] 2.2 Block the first stable capture with an explicit async barrier until the handler returns; assert exactly one stable-capture entry while recordId is still null, then release and await operation completion before asserting exactly one Insert
- [x] 2.3 Remove the helper dependency on a second capture and its fixed 3-second wait; use bounded completion signals and release barriers in cleanup
- [x] 2.4 Add direct-handler tests for backup when already WeightStabilized with null recordId, and no create when recordId is set; these do not prove continuous-sampling retries
- [x] 2.5 Convert DelayedSecondCreate_AfterOffScale_Reproduces_ClosedOverWeightWithNextPlate to a regression for the eliminated second task: use one direct stable callback, verify one task while first capture is blocked, finish the first record, then drive normal OffScale and a new plate without a new stabilize; assert no second stable task or old-weight record. Do not require invalidation of the sole first task across ResetCycle
- [x] 2.6 Preserve CreateWeighingRecordAsync_WhenRecordIdAlreadySet_StillInsertsAgain as characterization of the out-of-scope missing entry guard

## 3. Implementation verification

- [x] 3.1 Run WeighingStableWeightCarryoverReproductionTests and AttendedWeighingSoundFireAndForgetTests; record commands and results; verify the regression fails on the unmodified dual-enqueue implementation
- [x] 3.2 Confirm one direct transition callback schedules one stable create and no same-callback backup create; use scheduling/capture evidence rather than only the first observed Insert
- [x] 3.3 Run openspec validate fix-weighing-stable-single-enqueue --strict

## 4. Runtime acceptance (ICD target: L2)

Pre-fix FEV is optional supplementary diagnosis, not an implementation prerequisite. Its pending verdict is not completed runtime evidence. The defect-reproduction Graph's expectation of duplicate rows is not a post-fix acceptance criterion.

- [ ] 4.1 In the target client using a test scale, record code baseline, relevant configuration, steps, logs and record IDs for stable weighing, normal departure, and the next vehicle's stable weighing
- [ ] 4.2 Verify no same-callback transition-plus-backup scheduling, expected weight/plate association, normal capture and cycle reset; document failures without claiming cycle-wide deduplication or general late-task protection
- [ ] 4.3 Report L2 only with runtime evidence. If the environment is unavailable, leave runtime tasks unchecked and report implementation/test status separately from capability acceptance
