## ADDED Requirements

### Requirement: UrbanPassageRecord persists AccessCode

The `UrbanPassageRecord` entity SHALL expose the site access code as property `AccessCode` (`string?`). The database column MUST be named `AccessCode` (renamed from legacy `BuildLicenseNo`, values preserved). The entity MUST NOT expose `BuildLicenseNo`. Type-owned factories MUST assign `AccessCode` from ingest input that MAY still be named `BuildLicenseNo` on the DTO. Ingest JSON MAY keep `buildLicenseNo`.

#### Scenario: Entity property is AccessCode

- **WHEN** a checkpoint or finished-product passage row is created
- **THEN** the entity SHALL persist `AccessCode`
- **AND** MUST NOT expose `BuildLicenseNo` on the entity type

#### Scenario: Factory maps DTO BuildLicenseNo to AccessCode

- **WHEN** a passage factory receives input with `BuildLicenseNo` set
- **THEN** the created `UrbanPassageRecord.AccessCode` SHALL equal that value

#### Scenario: Column renamed with data preserved

- **WHEN** the EF migration runs on a database with passage column `BuildLicenseNo`
- **THEN** the column SHALL be renamed to `AccessCode`
- **AND** existing values MUST be preserved
