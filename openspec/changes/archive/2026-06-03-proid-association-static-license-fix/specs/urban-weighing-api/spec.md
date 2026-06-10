## MODIFIED Requirements

### Requirement: UrbanWeighingRecord extended fields

The `UrbanWeighingRecord` entity (currently `Entity<long>` PK) SHALL include the following fields beyond what is currently implemented: `VehicleColor` (string?), `PlateColor` (string?), `VehicleType` (string?), `DeviceId` (string?), `BuildLicenseNo` (string?), `FdBuildLicenseNo` (string?), `SiteType` (string?), `ProId` (string?), `ProName` (string?), `IsAnomaly` (bool, default false), `ClientSyncType` (int?), `ClientSyncTime` (DateTime?), `ClientRetryCount` (int?), `ClientLastErrorTime` (DateTime?), `SyncTime` (DateTime?), `RetryCount` (int?), `LastErrorTime` (DateTime?). The `SnapImages` string field SHALL be removed.

#### Scenario: Full record creation with extended fields

- **WHEN** a POST request creates an UrbanWeighingRecord with all extended fields including FdBuildLicenseNo
- **THEN** all fields SHALL be persisted correctly to the database
- **AND** FdBuildLicenseNo SHALL be stored in the FdBuildLicenseNo column

#### Scenario: SnapImages removed

- **WHEN** the entity is mapped to the database
- **THEN** no `SnapImages` column SHALL exist on the `Urban_WeighingRecord` table

### Requirement: UrbanWeighingRecordDto extended with sync state fields

The `UrbanWeighingRecordDto` SHALL accept the following additional fields: `VehicleColor`, `PlateColor`, `VehicleType`, `DeviceId`, `BuildLicenseNo`, `FdBuildLicenseNo`, `SiteType`, `ProId`, `ProName`, `IsAnomaly`, `ClientSyncType`, `ClientSyncTime`, `ClientRetryCount`, `ClientLastErrorTime`. The DTO field names SHALL use PascalCase and rely on global camelCase JSON serialization for wire format.

#### Scenario: DTO round-trip with extended fields

- **WHEN** a MaterialClient.Urban POST request contains JSON with camelCase field names for all extended fields including fdBuildLicenseNo
- **THEN** the system SHALL correctly deserialize, persist, and return a success response
