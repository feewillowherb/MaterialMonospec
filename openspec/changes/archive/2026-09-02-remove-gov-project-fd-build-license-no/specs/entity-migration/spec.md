## MODIFIED Requirements

### Requirement: GovProject entity uses ABP Entity base class
`GovProject` SHALL inherit from `Entity<Guid>` with properties mapped to PascalCase English names: `Id` (Guid), `ProName` (string), `BuildLicenseNo` (string?), `AddTime` (DateTime?), `SyncStatus` (bool?), `LastSyncTime` (DateTime?), `DeleteStatus` (bool?). The entity SHALL NOT include `FdBuildLicenseNo`. The entity SHALL NOT use SqlSugar annotations.

#### Scenario: Entity can be instantiated with required fields
- **WHEN** a new `GovProject` is created with a name
- **THEN** `ProName` SHALL be set and `Id` SHALL be a non-empty Guid
- **AND** MUST NOT expose an `FdBuildLicenseNo` property

#### Scenario: Entity has no SqlSugar dependencies
- **WHEN** `GovProject.cs` is inspected
- **THEN** it SHALL NOT import any `SqlSugar` namespace

#### Scenario: EF model excludes FdBuildLicenseNo column
- **WHEN** the EF Core model for `GovProject` is configured
- **THEN** the `Gov_Project` table MUST NOT include an `FdBuildLicenseNo` column
