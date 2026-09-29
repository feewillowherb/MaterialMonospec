## MODIFIED Requirements

### Requirement: Urban extension creation lifecycle

The system SHALL create an `UrbanWeighingExtension` row when an Urban mode weighing record is created. Creation and association MUST be performed by `IUrbanWeighingExtensionService` (Domain Service), not by EF navigation or database cascades. The parent `WeighingRecord` MUST be persisted and assigned a non-zero `Id` before the extension row is inserted. When creation uses deferred anomaly evaluation (stable-weight create before cycle complete), the extension MUST be initialized with `SyncStatus.WeighingInProgress` so background upload MUST NOT pick it up until the cycle promotes the row to `Pending`.

#### Scenario: Extension creation on record creation

- **WHEN** a new `WeighingRecord` is created with `WeighingMode.UrbanMode` and persisted with a valid `Id`
- **THEN** `IUrbanWeighingExtensionService` MUST create a corresponding `UrbanWeighingExtension` row with `WeighingRecordId` equal to that `Id`
- **AND** when anomaly evaluation is deferred at create time, the extension MUST be initialized with `SyncStatus.WeighingInProgress`
- **AND** the extension MUST be initialized with `RetryCount = 0`
- **AND** the extension MUST be initialized with `LastErrorTime = null`

#### Scenario: Extension absence for other modes

- **WHEN** a `WeighingRecord` is created with any mode other than `UrbanMode` (Standard, SolidWaste)
- **THEN** the system MUST NOT create an `UrbanWeighingExtension` row

#### Scenario: Transactional consistency

- **WHEN** creating a `WeighingRecord` with its extension in Urban mode
- **THEN** both operations MUST occur within the same application `UnitOfWork` transaction
- **AND** failure to save the extension after the parent record is saved MUST result in rollback of the unit of work
- **AND** the extension MUST NOT be inserted with `WeighingRecordId = 0`

#### Scenario: Existing Pending rows remain upload-eligible

- **WHEN** an `UrbanWeighingExtension` already persisted with `SyncStatus.Pending` before this change
- **THEN** the system MUST NOT rewrite that row to `WeighingInProgress` on upgrade
- **AND** the row MUST remain eligible for `GetPendingForUploadAsync`

## ADDED Requirements

### Requirement: Promote WeighingInProgress to Pending when cycle is ready

The system SHALL promote an Urban weighing extension from `SyncStatus.WeighingInProgress` to `SyncStatus.Pending` only after the weighing cycle is ready for upload and anomaly state has been formally evaluated (not the deferred placeholder alone). Promotion MUST occur on vehicle off-scale (cycle end) at minimum; manual edit paths that already set `Pending` remain valid.

#### Scenario: Off-scale promotes to Pending after formal anomaly evaluation

- **WHEN** an Urban weighing cycle reaches off-scale (or equivalent cycle-complete side effect) for a record whose extension is `WeighingInProgress`
- **THEN** the system MUST run formal anomaly evaluation for that record
- **AND** MUST set `SyncStatus` to `Pending`
- **AND** MUST NOT leave the extension as `WeighingInProgress` after successful promotion

#### Scenario: Recalculate while still WeighingInProgress does not upload

- **WHEN** `RecalculateAnomalyAfterLprOrCycleAsync` (or equivalent) updates `IsAnomaly` while `SyncStatus` is `WeighingInProgress`
- **THEN** the extension MUST remain `WeighingInProgress` until off-scale (or edit) promotion
- **AND** `GetPendingForUploadAsync` MUST NOT return that extension

#### Scenario: Synced record with later anomaly change returns to Pending

- **WHEN** formal anomaly recalculation changes anomaly state after the extension was already `Synced`
- **THEN** the system MUST set `SyncStatus` to `Pending` so the next poll can re-upload
