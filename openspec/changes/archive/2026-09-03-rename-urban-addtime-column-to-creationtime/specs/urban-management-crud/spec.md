## ADDED Requirements

### Requirement: Project and sync output DTOs expose CreationTime

`GovProjectDto` and `GovSyncDataDto` SHALL expose `CreationTime` mapped from the entity audited `CreationTime`. They MUST NOT expose `AddTime`. Serialized JSON SHALL use `creationTime`.

#### Scenario: GovProjectDto From entity

- **WHEN** a `GovProject` is mapped to `GovProjectDto`
- **THEN** `CreationTime` SHALL equal `entity.CreationTime`
- **AND** the DTO MUST NOT have an `AddTime` property

## MODIFIED Requirements

### Requirement: Sync data listing with real database operations
The `SyncInfoController` SHALL use `IRepository<GovSyncData, int>` and `IRepository<GovLog, int>` for querying sync records and logs, replacing the `SampleDataProvider` mock implementation.

#### Scenario: Paged sync data list
- **WHEN** a POST request is sent to `/SyncInfo/PageList` with page and limit parameters
- **THEN** the system SHALL query `Gov_SyncData` table from the real database and return paginated results ordered by `CreationTime` descending

#### Scenario: Sync log query
- **WHEN** a GET request is sent to `/SyncInfo/LogList` with a `SyncId` parameter
- **THEN** the system SHALL query `Gov_Log` table filtered by `SyncId` and return all matching log entries
