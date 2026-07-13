## ADDED Requirements

### Requirement: GovProject stores project address and construction unit
The `GovProject` entity SHALL include nullable `ProAddress` and `ShigongUnitName` string properties for project location and construction unit name. The entity SHALL NOT include a persisted `ProductCode` property.

#### Scenario: Extended fields available on entity
- **WHEN** a `GovProject` is created or loaded
- **THEN** the entity SHALL expose `ProAddress` and `ShigongUnitName` properties
- **AND** SHALL NOT expose a `ProductCode` column or property for persistence

## MODIFIED Requirements

### Requirement: DTO mapping for government projects with UpdateDto
The system SHALL provide `GovProjectDto` and `GovProjectUpdateDto` with entity mapping methods for data transfer operations, following ABP patterns. `GovProjectDto` SHALL include `ProAddress` and `ShigongUnitName`. `GovProjectDto` SHALL NOT include `ProductCode`.

#### Scenario: FromEntity mapping
- **WHEN** calling `GovProjectDto.FromEntity(entity)`
- **THEN** system creates DTO with all entity properties mapped correctly including `ProAddress` and `ShigongUnitName`
- **AND** handles nullable properties appropriately
- **AND** SHALL NOT include `ProductCode` in the DTO

#### Scenario: ToEntity mapping for creation
- **WHEN** calling `GovProjectCreateDto.ToEntity()`
- **THEN** system creates new GovProject entity with provided properties
- **AND** generates new Guid for Id

#### Scenario: UpdateDto mapping
- **WHEN** calling `input.ToEntity(existingEntity)` with `GovProjectUpdateDto`
- **THEN** system updates existing `GovProject` entity with provided properties
- **AND** preserves existing Id, AddTime, LastSyncTime values
- **AND** updates only modifiable fields (ProName, BuildLicenseNo, FdBuildLicenseNo, SyncStatus)
- **AND** SHALL NOT change `ProAddress` or `ShigongUnitName` via update DTO in this change scope
