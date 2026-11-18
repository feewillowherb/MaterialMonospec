## MODIFIED Requirements

### Requirement: Promote WeighingInProgress to Pending when cycle is ready

The system SHALL promote an Urban weighing extension from `SyncStatus.WeighingInProgress` to `SyncStatus.Pending` only after the weighing cycle is ready for upload and anomaly state has been formally evaluated (not the deferred placeholder alone). When `WeighingConfiguration.EnableUploadOnStable` is false, or the Urban stable-upload path is not active, promotion MUST occur on vehicle off-scale (cycle end) at minimum; manual edit paths that already set `Pending` remain valid. When `EnableUploadOnStable` is true on the Urban weighing path, the system MUST also promote on the first successful `WeightStabilized` create of that cycle, using the existing formal anomaly evaluation and promote path, and MUST NOT wait for off-scale for that first promotion. A later off-scale finalize MUST NOT change sync status solely because the plate text changed. Manual edit paths that already set `Pending` remain valid.

#### Scenario: Off-scale promotes to Pending after formal anomaly evaluation

- **WHEN** `EnableUploadOnStable` is false and an Urban weighing cycle reaches off-scale for a record whose extension is `WeighingInProgress`
- **THEN** the system MUST run formal anomaly evaluation for that record
- **AND** MUST set `SyncStatus` to `Pending`
- **AND** MUST NOT leave the extension as `WeighingInProgress` after successful promotion

#### Scenario: Stable upload promotes before off-scale

- **WHEN** `EnableUploadOnStable` is true on the Urban weighing path and `WeightStabilized` creates a record whose extension is `WeighingInProgress`
- **THEN** the system MUST run formal anomaly evaluation for that record
- **AND** MUST set `SyncStatus` to `Pending` before off-scale
- **AND** MUST NOT leave the extension as `WeighingInProgress` after successful promotion

#### Scenario: Recalculate while still WeighingInProgress does not upload

- **WHEN** `RecalculateAnomalyAfterLprOrCycleAsync` (or equivalent) updates `IsAnomaly` while `SyncStatus` is `WeighingInProgress`
- **THEN** the extension MUST remain `WeighingInProgress` until a promote path runs (off-scale, stable upload when enabled, or edit)
- **AND** `GetPendingForUploadAsync` MUST NOT return that extension

#### Scenario: Synced record with later anomaly change returns to Pending

- **WHEN** formal anomaly recalculation changes anomaly state after the extension was already `Synced`
- **THEN** the system MUST set `SyncStatus` to `Pending` so the next poll can re-upload

#### Scenario: Plate rewrite alone does not change sync status

- **WHEN** off-scale rewrites the plate of a record whose extension is already `Pending` or `Synced`
- **AND** anomaly state does not change
- **THEN** the system MUST leave `SyncStatus` unchanged
