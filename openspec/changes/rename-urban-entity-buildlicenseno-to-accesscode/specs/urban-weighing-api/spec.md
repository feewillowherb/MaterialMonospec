## ADDED Requirements

### Requirement: UrbanWeighingRecord persists AccessCode

The `UrbanWeighingRecord` entity SHALL expose the site access code as property `AccessCode` (`string?`). The database column for this property MUST be named `AccessCode` (renamed from legacy `BuildLicenseNo` via migration that preserves existing values). The entity MUST NOT expose a `BuildLicenseNo` property. Receive / submit DTOs MAY continue to use property `BuildLicenseNo` / JSON `buildLicenseNo`; persistence MUST map that value onto `UrbanWeighingRecord.AccessCode`.

#### Scenario: Entity property is AccessCode

- **WHEN** a weighing record is persisted after receive
- **THEN** the stored entity property SHALL be `AccessCode`
- **AND** MUST NOT have a `BuildLicenseNo` property on the entity type

#### Scenario: Column renamed with data preserved

- **WHEN** the EF migration for this change runs on a database that had column `BuildLicenseNo`
- **THEN** the column SHALL be renamed to `AccessCode`
- **AND** existing cell values MUST be preserved

#### Scenario: DTO BuildLicenseNo maps to entity AccessCode

- **WHEN** receive input provides `buildLicenseNo` / `BuildLicenseNo`
- **THEN** the persisted `UrbanWeighingRecord.AccessCode` SHALL equal that value
