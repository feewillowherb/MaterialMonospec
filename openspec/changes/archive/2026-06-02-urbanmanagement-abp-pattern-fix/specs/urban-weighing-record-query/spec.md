## ADDED Requirements

### Requirement: Query urban weighing records with pagination
The system SHALL provide an API endpoint that allows users to query urban weighing records with pagination and filtering support.

#### Scenario: Successful paginated query
- **WHEN** user requests weighing record list with page=1 and limit=20
- **THEN** system returns first 20 records ordered by AddTime descending
- **AND** response includes total count of matching records
- **AND** response uses `UrbanWeighingRecordOutputDto` for data transfer

#### Scenario: Query with plate number search
- **WHEN** user provides searchText parameter
- **THEN** system filters records where PlateNumber contains the search text
- **AND** performs case-insensitive matching

#### Scenario: Query with time range filter
- **WHEN** user provides startTime parameter
- **THEN** system filters records where WeighTime is greater than or equal to startTime
- **AND** when endTime parameter is provided, also filters where WeighTime is less than or equal to endTime

#### Scenario: Query with all filters combined
- **WHEN** user provides searchText, startTime, and endTime parameters
- **THEN** system applies all filters in combination
- **AND** returns records matching all criteria

### Requirement: Receive urban weighing record
The system SHALL provide an API endpoint that receives urban weighing records from clients.

#### Scenario: Successful record reception
- **WHEN** client submits valid weighing record data with required ClientRecordId, TotalWeight, and WeighingTime
- **THEN** system creates new UrbanWeighingRecord entity
- **AND** sets AddTime to current time
- **AND** assigns generated Id
- **AND** returns the record Id

#### Scenario: Duplicate record detection
- **WHEN** client submits record with existing ClientRecordId
- **THEN** system returns existing record Id without creating duplicate
- **AND** preserves original record data

#### Scenario: Record with attachments
- **WHEN** client submits record with AttachmentIds list
- **THEN** system creates UrbanWeighingRecordAttachment join records
- **AND** associates each attachment with the weighing record

#### Scenario: Invalid record data
- **WHEN** client submits record with missing required fields
- **THEN** system returns validation error
- **AND** includes error message indicating which fields are missing or invalid

### Requirement: DTO mapping for urban weighing records
The system SHALL provide DTO classes with entity mapping methods for weighing records.

#### Scenario: FromEntity mapping for output
- **WHEN** calling `UrbanWeighingRecordOutputDto.FromEntity(entity)`
- **THEN** system creates DTO with all entity properties mapped correctly
- **AND** includes attachment information if present

#### Scenario: ToEntity mapping for input
- **WHEN** calling `UrbanWeighingRecordDto.ToEntity()`
- **THEN** system creates new UrbanWeighingRecord entity with provided properties
- **AND** preserves ClientRecordId for deduplication

### Requirement: ApplicationService inheritance
The system SHALL implement `UrbanWeighingRecordAppService` inheriting from `ApplicationService`.

#### Scenario: Service registration
- **WHEN** `UrbanWeighingRecordAppService` is defined as class inheriting `ApplicationService`
- **THEN** ABP automatically registers HTTP endpoints for all public methods
- **AND** generates Swagger documentation
- **AND** applies ABP conventions for routing

#### Scenario: Method naming convention
- **WHEN** service methods are named with `Async` suffix (e.g., `GetListAsync`)
- **THEN** ABP generates HTTP endpoints following RESTful conventions
- **AND** maps HTTP verbs appropriately (GET for queries, POST for creation)
