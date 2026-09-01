## ADDED Requirements

### Requirement: Unified passage upload service entry

MaterialClient.Urban SHALL expose one application service entry `IUrbanPassageUploadService.SubmitPassageRecordAsync(Guid passageRecordId)` for cloud upload of pending passage rows. The service MUST NOT use C# tuple types for return values or parameters; multi-value outcomes MUST use a named `record`.

#### Scenario: Checkpoint dispatch

- **WHEN** `SubmitPassageRecordAsync` is called for a pending row with `PassageSource` checkpoint
- **THEN** the client MUST call UrbanManagement checkpoint receive API
- **AND** MUST NOT call finished-product receive or weighing receive for that row

#### Scenario: Finished-product dispatch

- **WHEN** `SubmitPassageRecordAsync` is called for a pending row with `PassageSource` finished-product
- **THEN** the client MUST call UrbanManagement finished-product receive API
- **AND** MUST NOT call checkpoint receive or weighing receive for that row

### Requirement: Passage submit DTO projects from entity

The client MUST build ingest payload using a named `record` type (for example `UrbanPassageSubmitDto`) with a static `FromPassage` factory on the DTO. The factory MUST map `UrbanPassageRecord` fields and set `clientRecordId` to the client passage row `Id`. Services MUST NOT assign DTO fields line by line.

#### Scenario: Idempotent client record id

- **WHEN** the same passage row is uploaded after a retry
- **THEN** the submit DTO MUST send the same `clientRecordId` as the local `UrbanPassageRecord.Id`
- **AND** UrbanManagement duplicate receive MUST update or return the existing server row per UM rules

### Requirement: Passage sync status on entity

`UrbanPassageRecord` SHALL carry `SyncStatus`, `RetryCount`, `LastErrorTime`, and `SubmitMachineCode`. New rows from LPR capture MUST start as `SyncStatus.Pending`. Successful upload MUST mark synced via type-owned entity methods.

#### Scenario: Pending after local create

- **WHEN** a passage row is created from LPR capture
- **THEN** `SyncStatus` MUST be `Pending`
- **AND** polling or event handler MAY upload it without manual UI action

#### Scenario: Failure retains pending

- **WHEN** upload fails due to network or server error
- **THEN** the row MUST remain or return to `Pending` for retry
- **AND** `RetryCount` and `LastErrorTime` MUST be updated

### Requirement: Refit APIs for passage receive

`IUrbanManagementApi` SHALL declare separate Refit methods for checkpoint and finished-product receive aligned with UrbanManagement routes. Both methods MUST accept the same client submit DTO `record` shape.

#### Scenario: API paths

- **WHEN** the client uploads checkpoint data
- **THEN** Refit MUST POST to `/api/app/urban-checkpoint-passage/receive`
- **WHEN** the client uploads finished-product data
- **THEN** Refit MUST POST to `/api/app/urban-finished-product-passage/receive`
