## ADDED Requirements

### Requirement: Query government projects with pagination
The system SHALL provide an API endpoint that allows users to query government projects with pagination support.

#### Scenario: Successful paginated query
- **WHEN** user requests project list with page=1 and limit=10
- **THEN** system returns first 10 non-deleted projects ordered by AddTime descending
- **AND** response includes total count of matching records
- **AND** response uses `GovProjectDto` for data transfer

#### Scenario: Query with search text
- **WHEN** user provides searchText parameter containing a project name or license number
- **THEN** system filters projects where ProName, BuildLicenseNo, or FdBuildLicenseNo contains the search text
- **AND** performs case-insensitive matching

### Requirement: Create new government project
The system SHALL provide an API endpoint that allows users to create new government projects.

#### Scenario: Successful project creation
- **WHEN** user submits project data with valid ProName and optional license numbers
- **THEN** system creates new GovProject entity with generated Guid
- **AND** sets AddTime to current time
- **AND** sets SyncStatus to false
- **AND** sets DeleteStatus to false
- **AND** returns created project as `GovProjectDto`

#### Scenario: Creation with empty project name
- **WHEN** user submits project data with empty or null ProName
- **THEN** system returns validation error
- **AND** includes error message indicating ProName is required

### Requirement: Update government project sync status
The system SHALL provide an API endpoint that allows users to toggle the sync status of a government project.

#### Scenario: Successful status toggle
- **WHEN** user requests to toggle sync status for valid project ID
- **THEN** system inverts the current SyncStatus value
- **AND** returns success response with updated project data

#### Scenario: Toggle with invalid project ID
- **WHEN** user requests to toggle status for non-existent or invalid Guid
- **THEN** system returns error response
- **AND** includes error message indicating invalid project ID

### Requirement: Delete government project
The system SHALL provide an API endpoint that allows users to mark government projects as deleted.

#### Scenario: Successful soft delete
- **WHEN** user requests deletion of valid project ID
- **THEN** system sets DeleteStatus to true
- **AND** preserves all other project data
- **AND** returns success response

#### Scenario: Delete with invalid project ID
- **WHEN** user requests deletion of non-existent or invalid Guid
- **THEN** system returns error response
- **AND** includes error message indicating invalid project ID

### Requirement: DTO mapping for government projects
The system SHALL provide `GovProjectDto` with entity mapping methods.

#### Scenario: FromEntity mapping
- **WHEN** calling `GovProjectDto.FromEntity(entity)`
- **THEN** system creates DTO with all entity properties mapped correctly
- **AND** handles nullable properties appropriately

#### Scenario: ToEntity mapping for creation
- **WHEN** calling `GovProjectCreateDto.ToEntity()`
- **THEN** system creates new GovProject entity with provided properties
- **AND** generates new Guid for Id
