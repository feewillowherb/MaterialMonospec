## MODIFIED Requirements

### Requirement: Project CRUD with ABP auto-generated API endpoints
The `GovProjectAppService` SHALL use ABP auto-generated REST API endpoints following ABP conventions, replacing custom MVC controller endpoints. Supported operations: paged list query, create new project, update project, set sync status, and delete project. All endpoints use ABP standard DTOs.

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

### Requirement: DTO mapping for government projects with UpdateDto
The system SHALL provide `GovProjectUpdateDto` with entity mapping methods for update operations, following ABP patterns.

#### Scenario: UpdateDto mapping
- **WHEN** calling `input.ToEntity(existingEntity)` with `GovProjectUpdateDto`
- **THEN** system updates existing `GovProject` entity with provided properties
- **AND** preserves existing Id, AddTime, LastSyncTime values
- **AND** updates only modifiable fields (ProName, BuildLicenseNo, FdBuildLicenseNo, SyncStatus)

### Requirement: ApplicationService method naming with ABP conventions
`GovProjectAppService` methods SHALL follow ABP naming conventions to enable proper HTTP verb mapping and endpoint generation.

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

## REMOVED Requirements

### Requirement: Project CRUD with MVC controller endpoints
**Reason**: Replaced by ABP auto-generated API endpoints which provide automatic routing, Swagger documentation, and standardized error handling.

**Migration**:
- Frontend: Update AJAX calls from `/Project/PageList`, `/Project/Add`, `/Project/SetStatus`, `/Project/Del` to `/api/app/gov-project/get-list`, `/api/app/gov-project/create`, `/api/app/gov-project/set-sync-status`, `/api/app/gov-project/delete`
- Backend: Remove any custom MVC controller actions (if they exist) and rely on `GovProjectAppService` ApplicationService auto-generated endpoints

### Requirement: Custom PagedResult pagination
**Reason**: Replaced by ABP's `PagedResultDto<T>` which integrates with ABP's ecosystem, Swagger generation, and JavaScript client proxies.

**Migration**:
- Backend: Replace `PagedResult<T>(data, total)` with `new PagedResultDto<T> { Items = data, TotalCount = total }`
- Frontend: Update response handling from `res.data` and `res.total` to `res.items` and `res.totalCount`
- Delete: Remove `PagedResult.cs` class after migration is complete

## ADDED Requirements

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
