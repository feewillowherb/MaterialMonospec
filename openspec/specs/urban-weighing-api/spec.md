# Urban Weighing API

## Purpose

Provides the core API for urban weighing record management, supporting extended fields for vehicle information, sync state management, and attachment file associations. (TBD: expand with API design principles)

## Requirements

### Requirement: UrbanWeighingRecord extended fields
The `UrbanWeighingRecord` entity (currently `Entity<long>` PK) SHALL include the following fields beyond what is currently implemented: `VehicleColor` (string?), `PlateColor` (string?), `VehicleType` (string?), `DeviceId` (string?), `BuildLicenseNo` (string?), `FdBuildLicenseNo` (string?), `SiteType` (string?), `ProId` (string?), `ProName` (string?), `IsAnomaly` (bool, default false), `ClientSyncType` (int?), `ClientSyncTime` (DateTime?), `ClientRetryCount` (int?), `ClientLastErrorTime` (DateTime?), `SyncTime` (DateTime?), `RetryCount` (int?), `LastErrorTime` (DateTime?). The `SnapImages` string field SHALL be removed.

#### Scenario: Full record creation with extended fields
- **WHEN** a POST request creates an UrbanWeighingRecord with all extended fields including FdBuildLicenseNo
- **THEN** all fields SHALL be persisted correctly to the database
- **AND** FdBuildLicenseNo SHALL be stored in the FdBuildLicenseNo column

#### Scenario: SnapImages removed
- **WHEN** the entity is mapped to the database
- **THEN** no `SnapImages` column SHALL exist on the `Urban_WeighingRecord` table

### Requirement: ClientRecordId idempotency
The system SHALL enforce uniqueness on `ClientRecordId`. If a record with the same `ClientRecordId` already exists, the system SHALL return the existing record's ID without creating a duplicate.

#### Scenario: First submission
- **WHEN** a record with `ClientRecordId: 12345` is submitted and no record with that ID exists
- **THEN** a new record SHALL be created and its ID returned

#### Scenario: Duplicate submission
- **WHEN** a record with `ClientRecordId: 12345` is submitted and a record with that ID already exists
- **THEN** the existing record's ID SHALL be returned and no new record created

### Requirement: UrbanWeighingRecordDto extended with sync state fields
The `UrbanWeighingRecordDto` SHALL accept the following additional fields: `VehicleColor`, `PlateColor`, `VehicleType`, `DeviceId`, `BuildLicenseNo`, `FdBuildLicenseNo`, `SiteType`, `ProId`, `ProName`, `IsAnomaly`, `ClientSyncType`, `ClientSyncTime`, `ClientRetryCount`, `ClientLastErrorTime`. The DTO field names SHALL use PascalCase and rely on global camelCase JSON serialization for wire format.

#### Scenario: DTO round-trip with extended fields
- **WHEN** a MaterialClient.Urban POST request contains JSON with camelCase field names for all extended fields including fdBuildLicenseNo
- **THEN** the system SHALL correctly deserialize, persist, and return a success response

### Requirement: Attachment association on receive
When a new `UrbanWeighingRecord` is created via the API, the system SHALL accept an optional list of `AttachmentFile` IDs and create `UrbanWeighingRecordAttachment` join records linking the new weighing record to the specified attachments.

#### Scenario: Record with attachments
- **WHEN** a POST request includes `AttachmentIds: ["guid1", "guid2"]` along with the weighing data
- **THEN** the system SHALL create the record and two `UrbanWeighingRecordAttachment` records linking to the specified attachment files

#### Scenario: Record without attachments
- **WHEN** a POST request does not include any attachment IDs
- **THEN** the system SHALL create the record without any attachment associations

### Requirement: Anomaly flag prevents government sync
When `IsAnomaly` is `true` on an `UrbanWeighingRecord`, the record SHALL NOT be included in the government sync pipeline. The background worker SHALL skip records marked as anomalous.

#### Scenario: Anomalous record excluded from sync
- **WHEN** the background sync worker queries pending records and a record has `IsAnomaly = true`
- **THEN** that record SHALL NOT be forwarded to the government API

#### Scenario: Normal record included in sync
- **WHEN** the background sync worker queries pending records and a record has `IsAnomaly = false`
- **THEN** that record SHALL be eligible for forwarding

### Requirement: Urban weighing record approval API

UrbanManagement SHALL expose an application service method to approve (correct) an existing `UrbanWeighingRecord` by server primary key, aligned with MaterialClient.Urban approval semantics.

#### Scenario: Approve via ABP conventional API

- **WHEN** an authenticated administrator sends `POST /api/app/urban-weighing-record/approve` (ABP conventional route) with a valid body containing `id`, `plateNumber`, and `totalWeight`
- **THEN** the system SHALL invoke `IUrbanWeighingRecordAppService.ApproveAsync`
- **AND** SHALL return the updated record representation (e.g. `UrbanWeighingRecordOutputDto`)

#### Scenario: Record not found

- **WHEN** `ApproveAsync` is called with a non-existent `id`
- **THEN** the system SHALL return an error indicating the record was not found

#### Scenario: Validation failure returns client-aligned errors

- **WHEN** plate validation or weight validation fails
- **THEN** the API SHALL return HTTP 400 with a clear validation message
- **AND** SHALL NOT update the entity
