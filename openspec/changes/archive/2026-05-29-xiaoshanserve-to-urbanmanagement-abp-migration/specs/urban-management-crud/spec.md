## ADDED Requirements

### Requirement: Project CRUD with real database operations
The `ProjectController` SHALL use `IRepository<GovProject, Guid>` for all CRUD operations, replacing the `SampleDataProvider` mock implementation. Supported operations: paged list query, add new project, set sync status, and delete project.

#### Scenario: Paged project list
- **WHEN** a POST request is sent to `/Project/PageList` with page and limit parameters
- **THEN** the system SHALL query `Gov_Project` table from the real database and return paginated results

#### Scenario: Add new project
- **WHEN** a POST request is sent to `/Project/Add` with project name and access codes
- **THEN** the system SHALL insert a new `GovProject` record into the database and return success

#### Scenario: Set sync status
- **WHEN** a POST request is sent to `/Project/SetStatus` with a project ID and status flag
- **THEN** the system SHALL update the `SyncStatus` field on the corresponding `GovProject` record

#### Scenario: Delete project
- **WHEN** a POST request is sent to `/Project/Del` with a project ID
- **THEN** the system SHALL update the `DeleteStatus` field to true on the corresponding `GovProject` record

### Requirement: Sync data listing with real database operations
The `SyncInfoController` SHALL use `IRepository<GovSyncData, int>` and `IRepository<GovLog, int>` for querying sync records and logs, replacing the `SampleDataProvider` mock implementation.

#### Scenario: Paged sync data list
- **WHEN** a POST request is sent to `/SyncInfo/PageList` with page and limit parameters
- **THEN** the system SHALL query `Gov_SyncData` table from the real database and return paginated results ordered by `AddTime` descending

#### Scenario: Sync log query
- **WHEN** a GET request is sent to `/SyncInfo/LogList` with a `SyncId` parameter
- **THEN** the system SHALL query `Gov_Log` table filtered by `SyncId` and return all matching log entries

### Requirement: SampleDataProvider removal
The `SampleDataProvider` class and `ISampleDataProvider` interface SHALL be removed from the project after all controllers have been migrated to use real database operations.

#### Scenario: No references to SampleDataProvider
- **WHEN** the codebase is searched for references to `SampleDataProvider` or `ISampleDataProvider`
- **THEN** no references SHALL exist in any controller or service

### Requirement: GovProject access-code indexes
The database SHALL have indexes on `GovProject.BuildLicenseNo` and `GovProject.FdBuildLicenseNo` to support efficient access-code lookups during legacy API validation and sync worker project resolution.

#### Scenario: Index creation
- **WHEN** the EF Core model is configured
- **THEN** indexes SHALL be created on both `BuildLicenseNo` and `FdBuildLicenseNo` columns of the `Gov_Project` table
