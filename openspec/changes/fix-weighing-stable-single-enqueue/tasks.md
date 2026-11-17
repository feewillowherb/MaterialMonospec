## 1. Orchestrator enqueue gate

- [ ] 1.1 In `AttendedWeighingService.OnWeightAndStatusChanged`, add a per-callback flag when status-transition enqueues `OnWeightStabilizedAsync`
- [ ] 1.2 Gate the backup check so it does not enqueue create when that flag is set (same callback)
- [ ] 1.3 Keep backup available when already WeightStabilized / later callbacks with `recordId == null` and no create enqueued this callback

## 2. Tests

- [ ] 2.1 Update `SingleStabilize_Reproduces_DoubleInsert_FromStatusAndBackupEnqueue` to expect a single `Insert` (rename if needed to a regression name)
- [ ] 2.2 Ensure the test still drives both former paths (transition + backup conditions) in one stabilize, asserting only one create

## 3. Verification

- [ ] 3.1 Run `WeighingStableWeightCarryoverReproductionTests` (and any renamed single-enqueue test) to confirm dual-enqueue path is fixed
- [ ] 3.2 Spot-check logs or test output: one stabilize → one `status transition` create schedule, no same-callback `backup check` enqueue
