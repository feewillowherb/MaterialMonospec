## MODIFIED Requirements

### Requirement: UrbanWeighingRecord extended fields

The `UrbanWeighingRecord` entity (currently `Entity<long>` PK) SHALL include the following fields beyond what is currently implemented: `VehicleColor` (string?), `PlateColor` (string?), `VehicleType` (string?), `DeviceId` (string?), `BuildLicenseNo` (string?), `FdBuildLicenseNo` (string?), `SiteType` (string?), `ProId` (string?), `ProName` (string?), `IsAnomaly` (bool, default false), `ClientSyncType` (int?), `ClientSyncTime` (DateTime?), `ClientRetryCount` (int?), `ClientLastErrorTime` (DateTime?), `SyncTime` (DateTime?), `RetryCount` (int?), `LastErrorTime` (DateTime?), `ServerApprovedAt` (DateTime?), `ClientApprovalAckAt` (DateTime?). The `SnapImages` string field SHALL be removed.

#### Scenario: Full record creation with extended fields

- **WHEN** a POST request creates an UrbanWeighingRecord with all extended fields including FdBuildLicenseNo
- **THEN** all fields SHALL be persisted correctly to the database
- **AND** FdBuildLicenseNo SHALL be stored in the FdBuildLicenseNo column

#### Scenario: SnapImages removed

- **WHEN** the entity is mapped to the database
- **THEN** no `SnapImages` column SHALL exist on the `Urban_WeighingRecord` table

#### Scenario: Server approval sync columns nullable

- **WHEN** a new `UrbanWeighingRecord` is created via `ReceiveAsync`
- **THEN** `ServerApprovedAt` and `ClientApprovalAckAt` MUST default to null
- **AND** MUST NOT block record creation or government sync eligibility

## ADDED Requirements

### Requirement: Ack approval sync API

UrbanManagement SHALL expose `IUrbanWeighingRecordAppService.AckApprovalSyncAsync` accepting `ClientRecordId` and setting `ClientApprovalAckAt` when `ServerApprovedAt` is set.

#### Scenario: ACK via conventional API

- **WHEN** MaterialClient sends a valid ACK request with `clientRecordId`
- **THEN** the system SHALL invoke `AckApprovalSyncAsync`
- **AND** SHALL persist `ClientApprovalAckAt`

### Requirement: Pull pending server approval sync API

UrbanManagement SHALL expose a query API returning records for a `ProId` where `ServerApprovedAt != null` and `ClientApprovalAckAt == null`.

#### Scenario: Client fetches pending approvals

- **WHEN** MaterialClient requests pending server-approval sync for its project
- **THEN** the API SHALL return matching records with sync payload fields required for local application
