## MODIFIED Requirements

### Requirement: GovProject access-code indexes
The database SHALL have an index on `GovProject.BuildLicenseNo` to support efficient access-code lookups during sync worker project resolution and access-code validation. The database MUST NOT have an index on a removed `FdBuildLicenseNo` column.

#### Scenario: Index creation
- **WHEN** the EF Core model is configured
- **THEN** an index SHALL be created on the `BuildLicenseNo` column of the `Gov_Project` table
- **AND** MUST NOT create an index on `FdBuildLicenseNo`

### Requirement: DTO mapping for government projects with UpdateDto
The system SHALL provide `GovProjectDto` and `GovProjectUpdateDto` with entity mapping methods for data transfer operations, following ABP patterns. `GovProjectDto` SHALL include `ProAddress` and `ShigongUnitName`. `GovProjectDto` SHALL NOT include `ProductCode` or `FdBuildLicenseNo`.

#### Scenario: FromEntity mapping
- **WHEN** calling `GovProjectDto.FromEntity(entity)`
- **THEN** system creates DTO with all entity properties mapped correctly including `ProAddress` and `ShigongUnitName`
- **AND** handles nullable properties appropriately
- **AND** SHALL NOT include `ProductCode` or `FdBuildLicenseNo` in the DTO

#### Scenario: ToEntity mapping for creation
- **WHEN** calling `GovProjectCreateDto.ToEntity()`
- **THEN** system creates new GovProject entity with provided properties
- **AND** generates new Guid for Id
- **AND** MUST NOT set `FdBuildLicenseNo`

#### Scenario: UpdateDto mapping
- **WHEN** calling `input.ToEntity(existingEntity)` with `GovProjectUpdateDto`
- **THEN** system updates existing `GovProject` entity with provided properties
- **AND** preserves existing Id, AddTime, LastSyncTime values
- **AND** updates only modifiable fields (ProName, BuildLicenseNo, SyncStatus)
- **AND** SHALL NOT change `ProAddress` or `ShigongUnitName` via update DTO in this change scope
