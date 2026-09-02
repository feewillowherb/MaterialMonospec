## MODIFIED Requirements

### Requirement: Project CRUD with ABP auto-generated API endpoints

The `GovProjectAppService` SHALL use ABP auto-generated REST API endpoints following ABP conventions, replacing custom MVC controller endpoints. Supported operations: paged list query, create new project, update project, **set `IsSyncEnabled`**, and delete project. All endpoints use ABP standard DTOs. The paged list behavior SHALL include records created by external BasePlatform pull sync in addition to manually created records.

#### Scenario: Paged project list via ABP API

- **WHEN** a GET request is sent to `/api/app/gov-project/get-list` with `PagedAndSortedResultRequestDto` parameters
- **THEN** the system SHALL query `Gov_Project` table from the database
- **AND** return `PagedResultDto<GovProjectDto>` with `Items` and `TotalCount` properties
- **AND** each item SHALL expose `isSyncEnabled` (not `enableSync`)

#### Scenario: Create project via ABP API

- **WHEN** a POST request is sent to `/api/app/gov-project/create` with `GovProjectCreateDto`
- **THEN** the system SHALL insert a new `GovProject` record into the database
- **AND** return created `GovProjectDto` with generated Guid Id
- **AND** `IsSyncEnabled` SHALL default to `false` when not supplied

#### Scenario: Update project via ABP API

- **WHEN** a PUT request is sent to `/api/app/gov-project/update` with `EntityDto<Guid>` id and `GovProjectUpdateDto`
- **THEN** the system SHALL update the corresponding `GovProject` record
- **AND** return updated `GovProjectDto`

#### Scenario: Set IsSyncEnabled via ABP API

- **WHEN** a client calls `SetIsSyncEnabledAsync` (ABP route under `gov-project`) with project ID and `isSyncEnabled`
- **THEN** the system SHALL update `GovProject.IsSyncEnabled` on the corresponding record
- **AND** return updated `GovProjectDto`
- **AND** MUST NOT use an `EnableSync` / `enableSync` field name

#### Scenario: Delete project via ABP API

- **WHEN** a DELETE request is sent to `/api/app/gov-project/delete` with `EntityDto<Guid>` containing project ID
- **THEN** the system SHALL soft-delete the corresponding `GovProject` record

#### Scenario: List includes pull-synced projects

- **WHEN** external BasePlatform pull sync inserts new `GovProject` rows
- **THEN** subsequent `/api/app/gov-project/get-list` responses SHALL include those rows
- **AND** those rows SHALL follow the same DTO shape and pagination behavior as manually created projects

### Requirement: DTO mapping for government projects with UpdateDto

The system SHALL provide `GovProjectDto` and `GovProjectUpdateDto` with entity mapping methods for data transfer operations, following ABP patterns. `GovProjectDto` SHALL include `ProAddress`, `ShigongUnitName`, and **`IsSyncEnabled` (`bool`)**. `GovProjectDto` SHALL NOT include `ProductCode` or `EnableSync`.

#### Scenario: FromEntity mapping

- **WHEN** calling `GovProjectDto.FromEntity(entity)`
- **THEN** system creates DTO with all entity properties mapped correctly including `ProAddress`, `ShigongUnitName`, and `IsSyncEnabled`
- **AND** SHALL NOT include `EnableSync` or `ProductCode` in the DTO

#### Scenario: ToEntity mapping for creation

- **WHEN** calling `GovProjectCreateDto.ToEntity()`
- **THEN** system creates new GovProject entity with provided properties
- **AND** `IsSyncEnabled` defaults to `false` when not set

#### Scenario: UpdateDto mapping

- **WHEN** calling `input.ToEntity(existingEntity)` with `GovProjectUpdateDto` that supplies `IsSyncEnabled`
- **THEN** system updates existing `GovProject.IsSyncEnabled` when the update value is present
- **AND** preserves existing Id and audit fields
