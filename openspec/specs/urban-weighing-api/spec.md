# Urban Weighing API

## Purpose

Provides the core API for urban weighing record management, supporting extended fields for vehicle information, sync state management, and attachment file associations. (TBD: expand with API design principles)
## Requirements
### Requirement: UrbanWeighingRecord extended fields

The `UrbanWeighingRecord` entity SHALL include extended fields including `SiteType` as **non-nullable `UrbanSiteType`** (default `Construction`), `ProId` as non-nullable `Guid`, sync fields as `SyncStatus` / non-nullable retry counts, and other vehicle/project fields as previously specified. The entity MUST NOT include `FdBuildLicenseNo`. `SnapImages` MUST NOT exist. Property name MUST remain `SiteType` (MUST NOT rename to `UrbanSiteType`).

#### Scenario: SiteType persisted as UrbanSiteType

- **WHEN** a weighing record is created or received with `siteType` of `Disposal`
- **THEN** `UrbanWeighingRecord.SiteType` SHALL equal `UrbanSiteType.Disposal`
- **AND** the database column SHALL store the enum as an integer

#### Scenario: Missing siteType defaults to Construction

- **WHEN** Receive omits `siteType` or the client sends the Construction value
- **THEN** the persisted `SiteType` SHALL be `UrbanSiteType.Construction`

#### Scenario: Receive rejects empty ProId

- **WHEN** `ReceiveAsync` receives a payload with missing `proId`, null `proId`, or `Guid.Empty`
- **THEN** the system SHALL reject the request with a validation or business error
- **AND** MUST NOT persist a weighing record

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
- **AND** the existing record's `SyncType` MUST be reset to `SyncStatus.Pending`
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
- **AND** the system MUST NOT insert additional attachment join rows for that existing record

### Requirement: UrbanWeighingRecordDto extended with sync state fields

The receive / DTO surface SHALL expose `SiteType` as **`UrbanSiteType`** (JSON `siteType`, string enum name). `ProId` SHALL be required `Guid`. The receive DTO MUST NOT include `FdBuildLicenseNo`.

#### Scenario: DTO round-trip with UrbanSiteType

- **WHEN** a MaterialClient.Urban POST includes `"siteType": "Disposal"` and a valid `proId`
- **THEN** the system SHALL deserialize to `UrbanSiteType.Disposal`, persist, and return success

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

### Requirement: Approval API is Web-only

`IUrbanWeighingRecordAppService.ApproveAsync` and the conventional route `POST /api/app/urban-weighing-record/approve` SHALL be used only by UrbanManagement Web administrators (`WeighingApproval.razor` / `/weighing-approval`). MaterialClient.Urban MUST NOT call this API or any client-specific variant (e.g. `ApproveWeighingRecordAsync` with `ClientRecordId`).

#### Scenario: Web administrator approves via ApproveAsync

- **WHEN** an authenticated administrator submits approval from the Web UI with server record `id`, `plateNumber`, `totalWeight`, and optional `LrpReplacementBase64`
- **THEN** the system SHALL invoke `ApproveAsync` and update the server record in place

#### Scenario: MaterialClient does not call Approve API

- **WHEN** the operator completes client-side approval in MaterialClient.Urban
- **THEN** the client MUST NOT send HTTP requests to the Approve endpoint
- **AND** MUST sync corrected fields and attachments via `ReceiveWeighingRecordAsync` after `SyncStatus` becomes `Pending`

#### Scenario: Client-specific Approve Refit method not used

- **WHEN** `IUrbanManagementApi` (or equivalent Refit interface) is configured for MaterialClient.Urban
- **THEN** it SHALL NOT expose `ApproveWeighingRecordAsync` or map to the Approve endpoint for client approval flows
- **AND** client weighing sync SHALL continue to use `ReceiveWeighingRecordAsync` and attachment upload APIs only

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

### Requirement: Weighing persist and output use CreationTime

The `UrbanWeighingRecords` table MUST store server ingestion time in column `CreationTime` (renamed from `AddTime` with values preserved). `UrbanWeighingRecordOutputDto` SHALL expose property `CreationTime` (JSON `creationTime`) mapped from `entity.CreationTime`. The output DTO MUST NOT expose `AddTime`. Receive input DTOs are unchanged (they do not carry ingestion time).

#### Scenario: List JSON uses creationTime

- **WHEN** `GetListAsync` returns a weighing record
- **THEN** the serialized item SHALL include `creationTime`
- **AND** MUST NOT include `addTime`

#### Scenario: Column rename preserves rows

- **WHEN** the rename migration runs
- **THEN** `UrbanWeighingRecords.CreationTime` SHALL exist
- **AND** `UrbanWeighingRecords.AddTime` MUST NOT exist
- **AND** row count MUST be unchanged

