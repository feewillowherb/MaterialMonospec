# Urban Management CRUD Operations

## Purpose

Provides real database CRUD operations for project and sync data management in the urban management system, replacing mock implementations with production-ready data access. (TBD: expand with data access strategy details)

## Requirements

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

### Requirement: DTO mapping for government projects
The system SHALL provide `GovProjectDto` with entity mapping methods for data transfer operations.

#### Scenario: FromEntity mapping
- **WHEN** calling `GovProjectDto.FromEntity(entity)`
- **THEN** system creates DTO with all entity properties mapped correctly
- **AND** handles nullable properties appropriately

#### Scenario: ToEntity mapping for creation
- **WHEN** calling `GovProjectCreateDto.ToEntity()`
- **THEN** system creates new GovProject entity with provided properties
- **AND** generates new Guid for Id

### Requirement: ApplicationService inheritance for project operations
The system SHALL implement `GovProjectAppService` inheriting from `ApplicationService` to handle project CRUD operations.

#### Scenario: Service registration
- **WHEN** `GovProjectAppService` is defined as class inheriting `ApplicationService`
- **THEN** ABP automatically registers HTTP endpoints for all public methods
- **AND** generates Swagger documentation
- **AND** applies ABP conventions for routing

#### Scenario: Method naming convention
- **WHEN** service methods are named with `Async` suffix (e.g., `GetListAsync`, `CreateAsync`)
- **THEN** ABP generates HTTP endpoints following RESTful conventions
- **AND** maps HTTP verbs appropriately (GET for queries, POST for creation)

### Requirement: DTO mapping for sync data and logs
The system SHALL provide DTO classes with entity mapping methods for sync data and logs.

#### Scenario: FromEntity mapping for sync data
- **WHEN** calling `GovSyncDataDto.FromEntity(entity)`
- **THEN** system creates DTO with all entity properties mapped correctly
- **AND** handles JSON serialization of SourceData field

#### Scenario: FromEntity mapping for sync logs
- **WHEN** calling `GovLogDto.FromEntity(entity)`
- **THEN** system creates DTO with all entity properties mapped correctly
- **AND** includes error information if present

### Requirement: ApplicationService inheritance for sync data operations
The system SHALL implement `GovSyncDataAppService` inheriting from `ApplicationService` to handle sync data query operations.

#### Scenario: Service registration
- **WHEN** `GovSyncDataAppService` is defined as class inheriting `ApplicationService`
- **THEN** ABP automatically registers HTTP endpoints for all public methods
- **AND** generates Swagger documentation
- **AND** applies ABP conventions for routing

#### Scenario: Method naming convention
- **WHEN** service methods are named with `Async` suffix (e.g., `GetListAsync`)
- **THEN** ABP generates HTTP endpoints following RESTful conventions
- **AND** maps HTTP verbs appropriately (GET for queries)

### Requirement: Legacy API compatibility
The system SHALL maintain compatibility with legacy government client API through a controller wrapper.

#### Scenario: Legacy request processing
- **WHEN** legacy client submits request to legacy endpoint
- **THEN** `LegacyApiController` receives the request
- **AND** delegates processing to `LegacyGovSyncAppService`
- **AND** returns response in legacy format

#### Scenario: Legacy sync result format
- **WHEN** `LegacyGovSyncAppService` processes request
- **THEN** returns `LegacyGovSyncResult` with success flag, message, and status code
- **AND** maintains compatibility with existing client expectations
