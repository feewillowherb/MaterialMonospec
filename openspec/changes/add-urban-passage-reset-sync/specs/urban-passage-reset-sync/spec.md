## ADDED Requirements

### Requirement: Checkpoint passage reset sync API

`UrbanCheckpointPassageAppService` SHALL expose `ResetSyncAsync(UrbanPassageResetSyncInputDto input)` returning `UrbanPassageListItemDto`. The method MUST use `[UnitOfWork]`. The service MUST load the row by `input.Id`, verify `PassageSource` is checkpoint, and apply sync reset via a type-owned method on `UrbanPassageRecord` (MUST NOT assign `SyncType` or `RetryCount` field-by-field in the service). When `SyncType` is success (1) or failure (2), the record MUST become pending sync (`SyncType = 0`, `RetryCount = 0`). When `SyncType` is pending (0) or null, the service MUST reject with a business error. Empty `Id` MUST be rejected.

#### Scenario: Reset failed checkpoint record

- **WHEN** operator calls reset sync for a checkpoint row with `SyncType = 2`
- **THEN** the row MUST have `SyncType = 0` and `RetryCount = 0`
- **AND** the API MUST return the updated list item DTO

#### Scenario: Reset successful checkpoint record

- **WHEN** operator calls reset sync for a checkpoint row with `SyncType = 1`
- **THEN** the row MUST have `SyncType = 0` and `RetryCount = 0`

#### Scenario: Reject pending checkpoint record

- **WHEN** operator calls reset sync for a checkpoint row with `SyncType = 0`
- **THEN** the service MUST throw a business exception
- **AND** MUST NOT change sync fields

#### Scenario: Reject non-checkpoint id on checkpoint API

- **WHEN** operator calls checkpoint reset sync with an id belonging to a finished-product row
- **THEN** the service MUST NOT reset that row
- **AND** MUST respond with not-found or invalid-source business error

### Requirement: Finished-product passage reset sync API

`UrbanFinishedProductPassageAppService` SHALL expose the same reset contract as checkpoint, scoped to `PassageSource` finished-product only.

#### Scenario: Reset failed finished-product record

- **WHEN** operator calls reset sync for a finished-product row with `SyncType = 2`
- **THEN** the row MUST have `SyncType = 0` and `RetryCount = 0`

#### Scenario: Reject checkpoint id on finished-product API

- **WHEN** operator calls finished-product reset sync with a checkpoint row id
- **THEN** the service MUST NOT reset that row

### Requirement: Reset sync input DTO

The system SHALL define `UrbanPassageResetSyncInputDto` in `UrbanManagement.Core.Models` with a single `Guid Id` property. API signatures MUST NOT use C# tuple types.

#### Scenario: DTO shape

- **WHEN** the reset sync endpoint is invoked
- **THEN** the request body MUST deserialize to `UrbanPassageResetSyncInputDto`
- **AND** MUST NOT require passage source in the payload

### Requirement: Checkpoint and finished-product list UI reset action

The checkpoint list page and finished-product list page SHALL show a per-row「重置同步」action when `SyncType` is 1 or 2 (TEMP, aligned with weighing list). The action MUST call the corresponding ApplicationService only (MUST NOT inject Repository or DbContext). After success, the page MUST refresh the list. While a row is resetting, the UI MUST indicate in-progress state. Failures MUST surface an operator-visible error message without silent failure.

#### Scenario: Checkpoint page shows reset for failed sync

- **WHEN** operator views the checkpoint list and a row shows sync failed
- **THEN** the row MUST offer reset sync
- **AND** confirming MUST call checkpoint `ResetSyncAsync`
- **AND** the row MUST show pending sync after refresh

#### Scenario: Finished-product page hides reset for pending sync

- **WHEN** a finished-product row is pending sync (`SyncType = 0`)
- **THEN** the reset action MUST NOT be offered for that row

### Requirement: Gov worker re-queue after reset

Reset sync MUST NOT require changes to Gov sync workers. After reset, checkpoint rows MUST become eligible for `GovCheckpointSyncManager` pending selection and finished-product rows for `GovProductSyncManager`, using existing `SyncType != 1` rules.

#### Scenario: Checkpoint re-queued

- **WHEN** a checkpoint row is reset from failed to pending
- **THEN** the next Gov checkpoint sync cycle MAY pick up that row without code changes to the worker
