## MODIFIED Requirements

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
