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
The system SHALL enforce uniqueness on `ClientRecordId`. If a record with the same `ClientRecordId` already exists, the system SHALL return the existing record's ID without creating a duplicate, and SHALL apply upsert updates to the existing record's correctable fields from the incoming DTO.

#### Scenario: First submission
- **WHEN** a record with `ClientRecordId: 12345` is submitted and no record with that ID exists
- **THEN** a new record SHALL be created and its ID returned

#### Scenario: Duplicate submission with corrected fields
- **WHEN** a record with `ClientRecordId: 12345` is submitted and a record with that ID already exists
- **AND** the payload contains updated `plateNumber`, `totalWeight`, and `isAnomaly: false`
- **THEN** the existing record's ID SHALL be returned
- **AND** no new record SHALL be created
- **AND** the existing record's `PlateNumber` and `TotalWeight` MUST reflect the payload values
- **AND** the existing record's `IsAnomaly` MUST be `false`
- **AND** the existing record's `SyncType` MUST be reset to `0`
- **AND** the existing record's `RetryCount` MUST be reset to `0`

#### Scenario: Duplicate submission idempotent retry
- **WHEN** a record with `ClientRecordId: 12345` is submitted and a record with that ID already exists
- **AND** the payload fields match the stored values
- **THEN** the existing record's ID SHALL be returned
- **AND** no duplicate record SHALL be created

#### Scenario: Duplicate submission ignores attachment updates
- **WHEN** a record with `ClientRecordId: 12345` is submitted and a record with that ID already exists
- **AND** the payload includes `attachmentIds` with one or more Guids
- **THEN** the existing record's attachment associations MUST remain unchanged
- **AND** the system MUST NOT insert additional `UrbanWeighingRecordAttachment` rows for that existing record

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

### Requirement: Client IsAnomaly persisted on receive without server recalculation

When UrbanManagement receives a weighing record from MaterialClient.Urban via `ReceiveAsync`, the system SHALL persist the `IsAnomaly` value from the request DTO and MUST NOT recalculate it using server-side threshold rules.

#### Scenario: Receive preserves client anomaly flag true

- **WHEN** `ReceiveAsync` receives a new record with `isAnomaly: true` from the client
- **THEN** the created `UrbanWeighingRecord.IsAnomaly` MUST be `true`
- **AND** no server anomaly detector MUST be invoked

#### Scenario: Receive preserves client anomaly flag false

- **WHEN** `ReceiveAsync` receives a new record with `isAnomaly: false` from the client
- **THEN** the created `UrbanWeighingRecord.IsAnomaly` MUST be `false`
- **AND** no server anomaly detector MUST be invoked

#### Scenario: Duplicate receive updates anomaly from client payload

- **WHEN** `ReceiveAsync` is called with an existing `ClientRecordId` (idempotent return path)
- **AND** the payload contains `isAnomaly: false` while the stored record has `IsAnomaly: true`
- **THEN** the system MUST update the stored record's `IsAnomaly` to `false` from the payload
- **AND** MUST NOT invoke server-side anomaly recalculation
- **AND** MUST return the existing record Id

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

#### Scenario: Non-anomalous record rejected

- **WHEN** `ApproveAsync` is called for a record with `IsAnomaly == false`
- **THEN** the API SHALL return HTTP 400 with a clear message that the record is not eligible for approval
- **AND** SHALL NOT update the entity

### Requirement: Receive 载荷 TotalWeight 单位为千克

`UrbanWeighingRecordReceiveInputDto.totalWeight`（及持久化字段 `UrbanWeighingRecord.TotalWeight`）SHALL 表示车辆总重，单位为**千克（kg）**。MaterialClient.Urban 上云时 MUST 在客户端完成吨→千克换算；UrbanManagement MUST NOT 假定该字段为吨。

#### Scenario: 接收并持久化千克重量

- **WHEN** `ReceiveAsync` 收到 `totalWeight: 8500`
- **THEN** 新建的 `UrbanWeighingRecord.TotalWeight` MUST 存为 `8500`
- **AND** 政府同步构造载荷时 `grossWeight` / `goodsWeight` MUST 使用该千克值

#### Scenario: 政府车型阈值按千克（大车）

- **WHEN** 已存 `TotalWeight` 为 `5000`（kg）
- **AND** `GovSyncBackgroundWorker` 构建政府出站载荷
- **THEN** 载荷字段 `carType` MUST 为 `"大车"`（因大于 4500 kg 阈值）

#### Scenario: 政府车型阈值按千克（小车）

- **WHEN** 已存 `TotalWeight` 为 `1000`（kg）
- **AND** `GovSyncBackgroundWorker` 构建政府出站载荷
- **THEN** 载荷字段 `carType` MUST 为 `"小车"`（因不大于 4500 kg 阈值）

### Requirement: Attachment upload endpoint for MaterialClient.Urban

UrbanManagement SHALL provide an application service endpoint (ABP conventional route) for MaterialClient.Urban to upload weighing-related images independently of `ReceiveAsync`, returning server-side `AttachmentFile` Guid values for use in `attachmentIds` on the receive payload.

#### Scenario: Conventional route for upload

- **WHEN** MaterialClient.Urban sends `POST` to the ABP-generated urban attachment upload route with valid JSON body
- **THEN** the system SHALL process images through `IFileService`
- **AND** SHALL return the list of created attachment Guids in the response body

### Requirement: End-to-end attachment association on receive

When MaterialClient.Urban calls receive with `attachmentIds` produced by the upload endpoint, the system SHALL create `UrbanWeighingRecordAttachment` join rows for a newly created weighing record.

#### Scenario: Receive with uploaded attachment Guids

- **WHEN** `ReceiveAsync` is called with a new `ClientRecordId` and `attachmentIds` containing Guids returned from the upload endpoint
- **THEN** the system SHALL insert the `UrbanWeighingRecord`
- **AND** SHALL create one `UrbanWeighingRecordAttachment` per Guid
- **AND** government sync worker SHALL later be able to read those files from `FilesPhysicalPath`-resolved storage

