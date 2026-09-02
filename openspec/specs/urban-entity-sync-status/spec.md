## Purpose

urban-entity-sync-status capability requirements.

### Requirement: SyncStatus enum on all sync-capable entities

UrbanManagement SHALL persist government/client sync state using the `SyncStatus` enum (`Pending`, `Success`, `Failed`) on `UrbanWeighingRecord`, `UrbanPassageRecord`, and `GovSyncData`. `SyncType` MUST be non-nullable with default `Pending` on insert. The system MUST NOT use raw `int` or `int?` for sync status on these entities.

#### Scenario: New weighing record defaults to pending

- **WHEN** a new `UrbanWeighingRecord` is created via `ReceiveAsync`
- **THEN** `SyncType` MUST be `SyncStatus.Pending`
- **AND** `RetryCount` MUST be `0`

#### Scenario: New passage record defaults to pending

- **WHEN** a new `UrbanPassageRecord` is created via checkpoint or finished-product receive
- **THEN** `SyncType` MUST be `SyncStatus.Pending`
- **AND** `RetryCount` MUST be `0`

### Requirement: RetryCount unified and non-nullable

`RetryCount` on `UrbanWeighingRecord`, `UrbanPassageRecord`, and `GovSyncData` MUST be non-nullable `int` with default `0`. `UrbanWeighingRecord.ClientRetryCount` MUST be non-nullable `int` with default `0`. `GovSyncData` MUST NOT expose a `SyncNumber` property; historical `SyncNumber` column MUST be migrated to `RetryCount`.

#### Scenario: GovSyncData column rename

- **WHEN** the database migration for this change is applied
- **THEN** the `GovSyncData` table MUST have a `RetryCount` column
- **AND** MUST NOT have a `SyncNumber` column

### Requirement: SyncStatus JSON as string enum names

UrbanManagement API responses and request bodies that expose `SyncType` or `ClientSyncType` MUST serialize enum values as JSON strings (`"Pending"`, `"Success"`, `"Failed"`), not numeric values.

#### Scenario: Weighing list API returns string sync status

- **WHEN** a client requests a weighing record list item with `SyncType = Success`
- **THEN** the JSON property for sync status MUST be the string `"Success"`

#### Scenario: Passage list API returns string sync status

- **WHEN** a client requests a passage list item with `SyncType = Failed`
- **THEN** the JSON property for sync status MUST be the string `"Failed"`

### Requirement: No new GovSyncData inserts

After this change, the system MUST NOT insert new rows into `GovSyncData`. Modern weighing receive and any Legacy stub MUST NOT call `InsertAsync` on `GovSyncData`. Existing historical rows MAY remain read-only.

#### Scenario: Modern receive does not dual-write

- **WHEN** `UrbanWeighingRecordAppService.ReceiveAsync` creates or updates a record
- **THEN** the system MUST NOT insert or update `GovSyncData` for that operation

#### Scenario: Legacy stub does not write GovSyncData

- **WHEN** a client calls the Legacy HTTP endpoint
- **THEN** the system MUST NOT insert into `GovSyncData`

### Requirement: Service layer uses SyncStatus enum only

Domain services and sync managers (`GovSyncManager`, `GovCheckpointSyncManager`, `GovProductSyncManager`, passage/weighing AppServices) MUST compare and assign `SyncStatus` enum members. The system MUST NOT use literal integers `0`, `1`, or `2` for sync status in application code.

#### Scenario: Passage sync manager marks success

- **WHEN** a checkpoint forward succeeds
- **THEN** the manager MUST set `record.SyncType = SyncStatus.Success`
- **AND** MUST NOT assign `SyncType = 1`
