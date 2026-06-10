## ADDED Requirements

### Requirement: Query government sync data with pagination
The system SHALL provide an API endpoint that allows users to query government sync data with pagination support.

#### Scenario: Successful paginated query
- **WHEN** user requests sync data list with page=1 and limit=10
- **THEN** system returns first 10 sync data records ordered by AddTime descending
- **AND** response includes total count of matching records
- **AND** response uses `GovSyncDataDto` for data transfer

#### Scenario: Query with search text
- **WHEN** user provides searchText parameter
- **THEN** system filters records where CarNo or ProName contains the search text
- **AND** performs case-insensitive matching

### Requirement: Query sync logs by sync data ID
The system SHALL provide an API endpoint that allows users to query sync logs for a specific sync data record.

#### Scenario: Successful log query
- **WHEN** user requests logs for valid sync data ID
- **THEN** system returns all associated GovLog records
- **AND** orders logs by SyncTime descending
- **AND** response uses `GovLogDto` for data transfer

#### Scenario: Query logs for non-existent sync data
- **WHEN** user requests logs for non-existent sync data ID
- **THEN** system returns empty list
- **AND** does not return error

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

### Requirement: ApplicationService inheritance
The system SHALL implement `GovSyncDataAppService` inheriting from `ApplicationService`.

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
