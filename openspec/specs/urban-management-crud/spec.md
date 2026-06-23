# Urban Management CRUD Operations

## Purpose

Provides real database CRUD operations for project and sync data management in the urban management system, replacing mock implementations with production-ready data access. (TBD: expand with data access strategy details)
## Requirements
### Requirement: Project CRUD with ABP auto-generated API endpoints
The `GovProjectAppService` SHALL use ABP auto-generated REST API endpoints following ABP conventions, replacing custom MVC controller endpoints. Supported operations: paged list query, create new project, update project, set sync status, and delete project. All endpoints use ABP standard DTOs. The paged list behavior SHALL include records created by external BasePlatform pull sync in addition to manually created records.

#### Scenario: Paged project list via ABP API
- **WHEN** a GET request is sent to `/api/app/gov-project/get-list` with `PagedAndSortedResultRequestDto` parameters
- **THEN** the system SHALL query `Gov_Project` table from the database
- **AND** return `PagedResultDto<GovProjectDto>` with `Items` and `TotalCount` properties
- **AND** ABP automatically generates Swagger documentation for this endpoint

#### Scenario: Create project via ABP API
- **WHEN** a POST request is sent to `/api/app/gov-project/create` with `GovProjectCreateDto`
- **THEN** the system SHALL insert a new `GovProject` record into the database
- **AND** return created `GovProjectDto` with generated Guid Id
- **AND** ABP automatically validates request using DTO validation attributes

#### Scenario: Update project via ABP API
- **WHEN** a PUT request is sent to `/api/app/gov-project/update` with `EntityDto<Guid>` id and `GovProjectUpdateDto`
- **THEN** the system SHALL update the corresponding `GovProject` record
- **AND** return updated `GovProjectDto`

#### Scenario: Set sync status via ABP API
- **WHEN** a PUT request is sent to `/api/app/gov-project/set-sync-status` with project ID and status flag
- **THEN** the system SHALL update the `SyncStatus` field on the corresponding `GovProject` record
- **AND** return updated `GovProjectDto`

#### Scenario: Delete project via ABP API
- **WHEN** a DELETE request is sent to `/api/app/gov-project/delete` with `EntityDto<Guid>` containing project ID
- **THEN** the system SHALL update the `DeleteStatus` field to true on the corresponding `GovProject` record
- **AND** ABP automatically maps DELETE verb to DeleteAsync method

#### Scenario: List includes pull-synced projects
- **WHEN** external BasePlatform pull sync inserts new `GovProject` rows
- **THEN** subsequent `/api/app/gov-project/get-list` responses SHALL include those rows
- **AND** those rows SHALL follow the same DTO shape and pagination behavior as manually created projects

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

### Requirement: ABP standard pagination DTOs
The system SHALL use ABP's `PagedAndSortedResultRequestDto` for input and `PagedResultDto<T>` for paginated responses, replacing custom pagination implementation.

#### Scenario: Paged request with ABP DTO
- **WHEN** client sends `PagedAndSortedResultRequestDto` with `SkipCount`, `MaxResultCount`, and `Sorting`
- **THEN** `GovProjectAppService.GetListAsync` receives these ABP-standard parameters
- **AND** applies pagination using `SkipCount` and `MaxResultCount`
- **AND** applies sorting using `Sorting` property if provided

#### Scenario: Paged response with ABP DTO
- **WHEN** `GovProjectAppService.GetListAsync` returns paginated results
- **THEN** response uses `PagedResultDto<GovProjectDto>` structure
- **AND** includes `Items` collection with current page data
- **AND** includes `TotalCount` with total record count for client pagination

### Requirement: Frontend ABP JavaScript API integration
The frontend SHALL use ABP's JavaScript API (`abp.ajax` or `abp.services`) for HTTP communication, replacing custom jQuery AJAX calls.

#### Scenario: Load project list via ABP AJAX
- **WHEN** user opens project list page
- **THEN** JavaScript calls `abp.ajax.get('/api/app/gov-project/get-list', params)`
- **AND** ABP automatically adds authentication headers
- **AND** ABP handles error responses with standardized error display
- **AND** UI renders `PagedResultDto.Items` in table

#### Scenario: Create project via ABP AJAX
- **WHEN** user submits create project form
- **THEN** JavaScript calls `abp.ajax.post('/api/app/gov-project/create', formData)`
- **AND** ABP shows loading indicator during request
- **AND** on success, UI refreshes list and shows success message
- **AND** on validation error, ABP displays field-level error messages

#### Scenario: Delete project via ABP AJAX
- **WHEN** user confirms project deletion
- **THEN** JavaScript calls `abp.ajax.delete('/api/app/gov-project/delete', { id: projectId })`
- **AND** ABP shows confirmation dialog
- **AND** on success, UI removes row from table and shows success message

### Requirement: EntityDto usage for entity operations
The system SHALL use ABP's `EntityDto<TKey>` for operations that reference entities by ID, following ABP conventions for update and delete operations.

#### Scenario: Delete with EntityDto
- **WHEN** calling DELETE `/api/app/gov-project/delete` with `EntityDto<Guid>` containing id
- **THEN** `GovProjectAppService.DeleteAsync(EntityDto<Guid> dto)` receives typed ID parameter
- **AND** ABP automatically binds the `id` property from request body

#### Scenario: Update with EntityDto
- **WHEN** calling PUT `/api/app/gov-project/update` with separate id parameter and update DTO
- **THEN** `GovProjectAppService.UpdateAsync(Guid id, GovProjectUpdateDto dto)` receives both parameters
- **AND** ABP automatically routes the id from URL or request body

### Requirement: GovProject access-code indexes
The database SHALL have indexes on `GovProject.BuildLicenseNo` and `GovProject.FdBuildLicenseNo` to support efficient access-code lookups during legacy API validation and sync worker project resolution.

#### Scenario: Index creation
- **WHEN** the EF Core model is configured
- **THEN** indexes SHALL be created on both `BuildLicenseNo` and `FdBuildLicenseNo` columns of the `Gov_Project` table

### Requirement: DTO mapping for government projects with UpdateDto
The system SHALL provide `GovProjectDto` and `GovProjectUpdateDto` with entity mapping methods for data transfer operations, following ABP patterns.

#### Scenario: FromEntity mapping
- **WHEN** calling `GovProjectDto.FromEntity(entity)`
- **THEN** system creates DTO with all entity properties mapped correctly
- **AND** handles nullable properties appropriately

#### Scenario: ToEntity mapping for creation
- **WHEN** calling `GovProjectCreateDto.ToEntity()`
- **THEN** system creates new GovProject entity with provided properties
- **AND** generates new Guid for Id

#### Scenario: UpdateDto mapping
- **WHEN** calling `input.ToEntity(existingEntity)` with `GovProjectUpdateDto`
- **THEN** system updates existing `GovProject` entity with provided properties
- **AND** preserves existing Id, AddTime, LastSyncTime values
- **AND** updates only modifiable fields (ProName, BuildLicenseNo, FdBuildLicenseNo, SyncStatus)

### Requirement: ApplicationService inheritance for project operations
The system SHALL implement `GovProjectAppService` inheriting from `ApplicationService` to handle project CRUD operations.

#### Scenario: Service registration
- **WHEN** `GovProjectAppService` is defined as class inheriting `ApplicationService`
- **THEN** ABP automatically registers HTTP endpoints for all public methods
- **AND** generates Swagger documentation
- **AND** applies ABP conventions for routing

#### Scenario: GetListAsync naming
- **WHEN** method is named `GetListAsync` with return type `Task<PagedResultDto<GovProjectDto>>`
- **THEN** ABP generates GET endpoint at `/api/app/gov-project/get-list`
- **AND** Swagger documents this as a query operation

#### Scenario: CreateAsync naming
- **WHEN** method is named `CreateAsync` with input `GovProjectCreateDto` and return `Task<GovProjectDto>`
- **THEN** ABP generates POST endpoint at `/api/app/gov-project/create`
- **AND** Swagger documents this as a create operation

#### Scenario: UpdateAsync naming
- **WHEN** method is named `UpdateAsync` with id and `GovProjectUpdateDto`
- **THEN** ABP generates PUT endpoint at `/api/app/gov-project/update`
- **AND** Swagger documents this as an update operation

#### Scenario: DeleteAsync naming
- **WHEN** method is named `DeleteAsync` with input `EntityDto<Guid>`
- **THEN** ABP generates DELETE endpoint at `/api/app/gov-project/delete`
- **AND** Swagger documents this as a delete operation

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

