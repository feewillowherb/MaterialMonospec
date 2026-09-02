## MODIFIED Requirements

### Requirement: UrbanWeighingRecord extended fields

The `UrbanWeighingRecord` entity (currently `Entity<long>` PK) SHALL include the following fields beyond what is currently implemented: `VehicleColor` (string?), `PlateColor` (string?), `VehicleType` (string?), `DeviceId` (string?), `BuildLicenseNo` (string?), `SiteType` (string?), `ProId` (**non-nullable `Guid`**), `ProName` (string?), `IsAnomaly` (bool, default false), `ClientSyncType` (`SyncStatus`, non-nullable), `ClientSyncTime` (DateTime?), `ClientRetryCount` (int, non-nullable), `ClientLastErrorTime` (DateTime?), `SyncType` (`SyncStatus`, non-nullable), `SyncTime` (DateTime?), `RetryCount` (int, non-nullable), `LastErrorTime` (DateTime?), `ServerApprovedAt` (DateTime?), `ClientApprovalAckAt` (DateTime?). The `SnapImages` string field SHALL be removed. The entity MUST NOT include `FdBuildLicenseNo`. `ProId` MUST NOT be `Guid.Empty` on create or receive paths.

#### Scenario: Full record creation with extended fields

- **WHEN** a POST request creates an UrbanWeighingRecord with all extended fields including BuildLicenseNo and a valid non-empty `ProId`
- **THEN** all fields SHALL be persisted correctly to the database
- **AND** MUST NOT create or persist an `FdBuildLicenseNo` column

#### Scenario: SnapImages removed

- **WHEN** the entity is mapped to the database
- **THEN** no `SnapImages` column SHALL exist on the `Urban_WeighingRecord` table

#### Scenario: Server approval sync columns nullable

- **WHEN** a new `UrbanWeighingRecord` is created via `ReceiveAsync`
- **THEN** `ServerApprovedAt` and `ClientApprovalAckAt` MUST default to null
- **AND** MUST NOT block record creation or government sync eligibility

#### Scenario: Receive rejects missing or empty ProId

- **WHEN** `ReceiveAsync` receives a payload with missing `proId`, null `proId`, or `Guid.Empty`
- **THEN** the system SHALL reject the request with a validation or business error
- **AND** MUST NOT persist a weighing record

### Requirement: UrbanWeighingRecordDto extended with sync state fields

The `UrbanWeighingRecordDto` / receive input SHALL accept `ProId` as **required `Guid`** (JSON `proId`). Other extended fields remain as specified. The receive DTO MUST NOT include `FdBuildLicenseNo`.

#### Scenario: DTO round-trip with extended fields

- **WHEN** a MaterialClient.Urban POST request contains JSON with camelCase field names for all extended fields including `proId` as a valid Guid and `buildLicenseNo`
- **THEN** the system SHALL correctly deserialize, persist, and return a success response
- **AND** MUST NOT require or persist `fdBuildLicenseNo`

#### Scenario: Unknown fdBuildLicenseNo in request body is ignored

- **WHEN** a legacy client POST includes `fdBuildLicenseNo` in the JSON body
- **THEN** the request SHALL still succeed if other fields are valid including `proId`
- **AND** the created or updated record MUST NOT store `fdBuildLicenseNo`
