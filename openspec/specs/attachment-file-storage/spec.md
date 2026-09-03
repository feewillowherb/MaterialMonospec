# Attachment File Storage

## Purpose

Provides file storage and management capabilities for image attachments in the urban management system, supporting both legacy government client compatibility and new urban weighing record features. (TBD: expand with architectural overview)
## Requirements
### Requirement: AttachmentFile entity for image storage

The system SHALL provide an `AttachmentFile` entity with fields: `Id` (Guid PK), `FileName` (string, max 200), `LocalPath` (string, max 1000), `AttachType` (`AttachType` enum, `short` underlying type, full definition aligned with `MaterialClient.Common.Entities.Enums.AttachType`: `UnmatchedEntryPhoto = 0`, `EntryPhoto = 1`, `ExitPhoto = 2`, `TicketPhoto = 3`, `Lrp = 5`, `UrbanPhoto = 6`), and `CreationTime` (DateTime, ABP audited; database column `CreationTime`). The entity SHALL map to the `AttachmentFile` database table. The entity MUST NOT expose `AddTime`.

#### Scenario: AttachmentFile entity creation

- **WHEN** an image is saved to disk during legacy or new client processing
- **THEN** the system SHALL create an `AttachmentFile` record with the file name, relative local path, appropriate `AttachType` enum value, and current timestamp in `CreationTime`

### Requirement: UrbanWeighingRecordAttachment join table
The system SHALL provide a `UrbanWeighingRecordAttachment` entity with fields: `Id` (Guid PK), `UrbanWeighingRecordId` (long, FK to UrbanWeighingRecord), `AttachmentFileId` (Guid, FK to AttachmentFile). The entity SHALL map to the `UrbanWeighingRecordAttachment` table with indexes on both foreign keys.

#### Scenario: Associating attachments with a weighing record
- **WHEN** a weighing record is created with associated images
- **THEN** the system SHALL create `UrbanWeighingRecordAttachment` records linking the weighing record to each `AttachmentFile`

### Requirement: Base64 image save and compress
The system SHALL accept an array of Base64-encoded image strings, decode them, save each to local disk at the path `{FilesPhysicalPath}/{buildLicenseNo}/{ticks}_{index}.jpg`, and automatically compress images exceeding the configured `CompressImage` KB threshold using JPEG quality 60.

#### Scenario: Image within size threshold
- **WHEN** a Base64 image decodes to 150 KB and the threshold is 200 KB
- **THEN** the system SHALL save the image without compression and create an `AttachmentFile` record

#### Scenario: Image exceeding size threshold
- **WHEN** a Base64 image decodes to 300 KB and the threshold is 200 KB
- **THEN** the system SHALL compress the image to JPEG quality 60 before saving, and create an `AttachmentFile` record

#### Scenario: Multiple images in one request
- **WHEN** a request contains 3 Base64 images
- **THEN** the system SHALL save all 3 as separate files and create 3 `AttachmentFile` records

### Requirement: Storage configuration via IOptions
The system SHALL bind storage configuration from `appsettings.json` to a `StorageOptions` class via `IOptions<T>`, including: `FilesPhysicalPath` (string, root directory for file storage), `CompressImage` (int, compression threshold in KB, default 200), and `GovAddress` (string, government API endpoint URL).

#### Scenario: Configuration loaded on startup
- **WHEN** the application starts with `appsettings.json` containing `"FilesPhysicalPath": "Uploads/"`, `"CompressImage": 200`, `"GovAddress": ""`
- **THEN** the `StorageOptions` SHALL be available via DI with these values

### Requirement: AttachType restricted to Lrp and UrbanPhoto

Although the `AttachType` enum defines all MaterialClient members, UrbanManagement attachment create/upload APIs and `FileService.SaveAndCompressImagesAsync` SHALL only accept `AttachType.Lrp` (5) and `AttachType.UrbanPhoto` (6). Other enum values MUST NOT be persisted via UrbanManagement APIs in this capability.

#### Scenario: Lrp attach type

- **WHEN** an image is saved from a license plate recognition upload
- **THEN** the `AttachmentFile.AttachType` SHALL be set to `AttachType.Lrp` (5)

#### Scenario: UrbanPhoto attach type

- **WHEN** an urban camera capture image is uploaded
- **THEN** the `AttachmentFile.AttachType` SHALL be set to `AttachType.UrbanPhoto` (6)

#### Scenario: Non-urban attach type rejected at API

- **WHEN** the upload API receives `attachType` of `0`, `1`, `2`, or `3` (or any value other than `5` or `6`)
- **THEN** the system SHALL reject the operation with HTTP 400
- **AND** SHALL NOT create `AttachmentFile` records

### Requirement: Attachment reading for sync forwarding
The system SHALL be able to read all `AttachmentFile` records associated with a `UrbanWeighingRecord`, load the image files from disk, and convert them to Base64 strings for forwarding to the government API.

#### Scenario: Reading attachments for forwarding
- **WHEN** the background sync worker processes a record with 2 associated attachments
- **THEN** the system SHALL load both files from disk, convert to Base64, and include them in the government API payload

### Requirement: FilesPhysicalPath resolves under service content root

UrbanManagement SHALL resolve `StorageOptions.FilesPhysicalPath` relative to the application content root (service run directory), not the client machine. When `FilesPhysicalPath` is `"Uploads/"`, persisted files SHALL be stored under `{ContentRoot}/Uploads/` (or equivalent base-directory combination used by `FileService`).

#### Scenario: Default Uploads folder at startup

- **WHEN** the service starts with `"FilesPhysicalPath": "Uploads/"` and content root `C:\Services\UrbanManagement`
- **THEN** the effective storage root SHALL be `C:\Services\UrbanManagement\Uploads\` (normalized path separators)
- **AND** `FileService` SHALL create the directory if missing or log a clear error if not writable

#### Scenario: Relative path stored in AttachmentFile

- **WHEN** an image is saved via `SaveAndCompressImagesAsync`
- **THEN** `AttachmentFile.LocalPath` SHALL be stored relative to the resolved `FilesPhysicalPath` root
- **AND** `ReadAttachmentFilesAsync` SHALL resolve the same root when loading files for government sync

### Requirement: MaterialClient.Urban attachment upload API

UrbanManagement SHALL expose an HTTP API callable by MaterialClient.Urban that accepts Base64-encoded images and `attachType` as the `AttachType` enum integer (`5` for Lrp, `6` for UrbanPhoto), persists files under `{FilesPhysicalPath}/{buildLicenseNo}/`, applies compression per existing rules, creates `AttachmentFile` entities with enum `AttachType`, and returns the created Guid identifiers. This Base64 JSON API remains supported for backward compatibility alongside the multipart binary upload API; it is the legacy path and MUST NOT be removed in this change.

#### Scenario: Successful batch upload with Lrp enum

- **WHEN** MaterialClient.Urban sends a valid request with `buildLicenseNo`, `attachType: 5` (Lrp), and one or more Base64 JPEG images
- **THEN** the server SHALL invoke `IFileService.SaveAndCompressImagesAsync` (or the shared byte-array save path it delegates to) with `AttachType.Lrp`
- **AND** SHALL return HTTP 200 with a list of created `AttachmentFile` Guid values
- **AND** persisted `AttachmentFile.AttachType` SHALL be `5`

#### Scenario: Successful batch upload with UrbanPhoto enum

- **WHEN** MaterialClient.Urban sends `attachType: 6` (UrbanPhoto)
- **THEN** the server SHALL persist attachments with `AttachType.UrbanPhoto` (6)

#### Scenario: Invalid attach type rejected

- **WHEN** the request specifies an attach type other than `5` or `6`
- **THEN** the server SHALL return HTTP 400 and SHALL NOT create `AttachmentFile` records

### Requirement: AttachType enum aligned with MaterialClient

UrbanManagement SHALL define `AttachType` with the same members and numeric values as `MaterialClient.Common.Entities.Enums.AttachType`, including `UnmatchedEntryPhoto` (0), `EntryPhoto` (1), `ExitPhoto` (2), `TicketPhoto` (3), `Lrp` (5), and `UrbanPhoto` (6).

#### Scenario: Full enum definition present

- **WHEN** UrbanManagement compiles `UrbanManagement.Core.Entities.Enums.AttachType`
- **THEN** all members and values SHALL match MaterialClient `AttachType`
- **AND** the enum SHALL use `short` as the underlying type

### Requirement: Attachment images classified by AttachType enum for Web display

When loading weighing record attachments for Web display (`GetApprovalAttachmentsAsync` / `FileService.GetApprovalAttachmentImagesAsync`), the system SHALL classify images by `AttachType` enum and return at most one Base64 image per type for `Lrp` and `UrbanPhoto` only.

#### Scenario: Classify and return Lrp and UrbanPhoto

- **WHEN** a weighing record has linked attachments with `AttachType.Lrp` and `AttachType.UrbanPhoto`
- **THEN** the API SHALL return `LrpImageBase64` and `UrbanPhotoImageBase64` populated from disk
- **AND** comparison SHALL use enum values, not string names

#### Scenario: Ignore non-urban attach types

- **WHEN** linked attachments include types other than `Lrp` or `UrbanPhoto`
- **THEN** those attachments SHALL be excluded from the Web display DTO
- **AND** SHALL NOT cause an error response

### Requirement: Multipart binary attachment upload API

UrbanManagement SHALL expose an HTTP API callable by MaterialClient.Urban that accepts `multipart/form-data` with form fields `buildLicenseNo`, `attachType` (`AttachType` enum integer `5` for Lrp or `6` for UrbanPhoto), and one or more binary image file parts, persists files under `{FilesPhysicalPath}/{buildLicenseNo}/`, applies compression per existing rules, creates `AttachmentFile` entities with enum `AttachType`, and returns the created Guid identifiers in the same response shape as the Base64 upload API (`attachmentIds`).

#### Scenario: Successful multipart batch with Lrp

- **WHEN** MaterialClient.Urban sends a valid multipart request with `buildLicenseNo`, `attachType: 5` (Lrp), and one or more JPEG (or other supported image) file parts
- **THEN** the server SHALL persist attachments via the shared file-save path used by Base64 upload (byte-array save and compress)
- **AND** SHALL return HTTP 200 with a list of created `AttachmentFile` Guid values
- **AND** persisted `AttachmentFile.AttachType` SHALL be `5`

#### Scenario: Successful multipart batch with UrbanPhoto

- **WHEN** MaterialClient.Urban sends `attachType: 6` (UrbanPhoto) with binary file parts
- **THEN** the server SHALL persist attachments with `AttachType.UrbanPhoto` (6)

#### Scenario: Multipart invalid attach type rejected

- **WHEN** the multipart request specifies an attach type other than `5` or `6`
- **THEN** the server SHALL return HTTP 400 and SHALL NOT create `AttachmentFile` records

#### Scenario: Multipart missing buildLicenseNo rejected

- **WHEN** `buildLicenseNo` is missing or whitespace-only
- **THEN** the server SHALL return HTTP 400 and SHALL NOT create `AttachmentFile` records

### Requirement: Base64 upload API retained during multipart rollout

UrbanManagement SHALL continue to expose the existing Base64 JSON attachment upload API (`IUrbanAttachmentAppService.UploadAsync` / conventional `POST` under `urban-attachment/upload`) with unchanged request and response contracts while multipart is the preferred client path. Removal of the Base64 upload API SHALL require a separate explicit change after all clients have migrated.

#### Scenario: Legacy Base64 client still uploads

- **WHEN** an older MaterialClient.Urban (or other caller) posts a valid Base64 JSON upload request to the legacy endpoint
- **THEN** the server SHALL save and compress images and return `attachmentIds` as today
- **AND** SHALL NOT require multipart

#### Scenario: Both APIs share persistence rules

- **WHEN** the same image bytes are uploaded once via Base64 and once via multipart with the same `buildLicenseNo` and `attachType`
- **THEN** both paths SHALL apply the same compression threshold and JPEG quality rules
- **AND** both SHALL create `AttachmentFile` rows with relative `LocalPath` under the resolved storage root

### Requirement: tusdotnet resumable attachment upload endpoint

UrbanManagement SHALL host a tus 1.0 resumable upload endpoint (via tusdotnet) under a dedicated path (recommended `/api/urban-attachment/tus`) that accepts Lrp/UrbanPhoto image uploads. Upload metadata SHALL include `buildlicenseno` and `attachtype` (`5` or `6`). When a tus upload completes, the server SHALL persist the assembled file bytes through the shared save-and-compress path used by multipart/Base64 upload and SHALL make the resulting `AttachmentFile` Guid available to the client through a thin HTTP API (because the tus protocol completion response does not carry business `attachmentIds`).

#### Scenario: Create tus upload with valid metadata

- **WHEN** the client creates a tus upload with `Upload-Length` within the configured maximum and metadata containing a non-empty `buildlicenseno` and `attachtype` of `5` or `6`
- **THEN** the server SHALL accept the creation and return a tus file URL/location
- **AND** SHALL NOT yet require multipart or Base64 APIs

#### Scenario: Reject invalid attach type at create

- **WHEN** the client creates a tus upload with `attachtype` other than `5` or `6`
- **THEN** the server SHALL reject the creation
- **AND** SHALL NOT create `AttachmentFile` records

#### Scenario: Patch chunks until complete then persist

- **WHEN** the client PATCHes consecutive chunks with definite offsets until the upload is complete
- **THEN** the server SHALL assemble the file via tusdotnet storage
- **AND** SHALL invoke the shared save-and-compress byte path with the metadata `buildlicenseno` and `attachtype`
- **AND** SHALL record a mapping from the tus file id to the created `AttachmentFile` Guid

#### Scenario: Client obtains attachment id after tus complete

- **WHEN** a tus upload has completed and been persisted
- **AND** the client calls the thin attachment-id API for that tus file id (or a batch commit of file ids)
- **THEN** the server SHALL return the corresponding `AttachmentFile` Guid value(s)
- **AND** the response shape for batch commit SHALL expose `attachmentIds` compatible with subsequent Receive usage

#### Scenario: Terminate cleans incomplete upload

- **WHEN** the client terminates an incomplete tus upload
- **THEN** the server SHALL remove temporary tus store data for that file
- **AND** SHALL NOT create `AttachmentFile` records for the terminated upload

### Requirement: tus upload expiry and size limits

UrbanManagement SHALL configure tusdotnet with a maximum upload size consistent with the existing approximately 16MB attachment ceiling and an expiration TTL for incomplete uploads (default 60 minutes), after which incomplete temporary data SHALL be removed and SHALL NOT produce `AttachmentFile` records.

#### Scenario: Oversized upload rejected

- **WHEN** a client creates a tus upload whose `Upload-Length` exceeds the configured maximum
- **THEN** the server SHALL reject the creation

#### Scenario: Expired incomplete upload not persisting

- **WHEN** an incomplete tus upload exceeds the configured expiration
- **THEN** the server SHALL not create `AttachmentFile` records from that expired upload

### Requirement: Multipart and Base64 APIs retained alongside tus upload

UrbanManagement SHALL continue to expose the existing multipart binary upload API and Base64 JSON upload API with unchanged contracts while tusdotnet upload is available as an optional path. Removal of either legacy path SHALL require a separate explicit change.

#### Scenario: Multipart still works

- **WHEN** a client posts a valid multipart upload while the tus endpoint is deployed
- **THEN** the server SHALL persist attachments and return `attachmentIds` as today

#### Scenario: Base64 still works

- **WHEN** a client posts a valid Base64 JSON upload while the tus endpoint is deployed
- **THEN** the server SHALL persist attachments and return `attachmentIds` as today

