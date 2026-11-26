# client-publicapi-attachment-sync Specification

## Purpose
TBD - created by archiving change refactor-client-oss-upload-to-publicapi. Update Purpose after archive.
## Requirements
### Requirement: Removal of client-side Aliyun OSS SDK and credentials

`MaterialClient` SHALL remove all direct Aliyun OSS upload code, configuration, and NuGet dependencies, including `IOssUploadService`, `OssUploadService`, `AliyunOssConfig`, `Aliyun.OSS.SDK.NetCore` package references, and `AliyunOss` sections in host `appsettings.secret.json` files. The client SHALL NOT hold OSS access keys, secrets, or bucket names.

#### Scenario: Client builds and runs without OSS configuration
- **WHEN** `MaterialClient` starts without any `AliyunOss` section in `appsettings.json` or `appsettings.secret.json`
- **THEN** the application SHALL start normally without throwing OSS configuration validation errors
- **AND** attachment synchronization SHALL use `IMaterialPlatformApi` instead of any OSS SDK client

### Requirement: Attachment upload via FdSoft.Material.PublicApi with pre-upload compression

`MaterialClient` SHALL upload pending waybill attachments (`EntryPhoto`, `ExitPhoto`, `TicketPhoto`) to `FdSoft.Material.PublicApi` via `IMaterialPlatformApi.UploadAttachmentAsync` (`POST /api/File/UploadAttachment`) using the existing JWT Bearer token handler. Before each upload, the client SHALL compress the image in memory to approximately 200KB (configurable via `AttachmentUpload:TargetMaxSizeKb`, default `200`) without modifying the original local image file on disk.

#### Scenario: Pending attachment is compressed in memory and uploaded
- **WHEN** `IAttachmentService.SyncPendingAttachmentsAsync` processes a pending attachment whose local file is 1.5MB
- **THEN** the client SHALL compress the image in memory to approximately 200KB while keeping the local file on disk untouched
- **AND** SHALL send the compressed bytes to `POST /api/File/UploadAttachment` via `IMaterialPlatformApi`
- **AND** upon receiving `success = true`, SHALL record the returned remote key/path in `AttachmentFile.OssFullPath` and set `AttachmentFile.LastSyncTime`

#### Scenario: Compression failure falls back to original bytes
- **WHEN** in-memory JPEG compression fails for a pending attachment
- **THEN** the client SHALL log a warning and upload the original file bytes without aborting the sync batch

### Requirement: Dedicated off-peak background worker with jitter and short transactions

`MaterialClient` SHALL decouple automatic attachment uploading from `PollingBackgroundService` into a dedicated `AttachmentUploadBackgroundService` configured via `AttachmentUploadOptions`. By default, automatic uploading SHALL run only during the configured off-peak window (`20:00` to `07:00` local time, `OffPeakWindowOnly = true`) with per-window random jitter (`MaxJitterMinutes`, default `30`), ensuring zero automatic upload traffic during daytime operations. Database access SHALL use short read and per-file write transactions rather than holding a SQLite UnitOfWork open across HTTP uploads.

#### Scenario: Daytime automatic upload is skipped
- **WHEN** `AttachmentUploadBackgroundService` ticks during daytime hours outside the configured off-peak window (e.g., 14:00 with window 20:00–07:00) and `OffPeakWindowOnly` is `true`
- **THEN** the worker SHALL immediately skip uploading without issuing HTTP requests or opening write transactions

#### Scenario: Off-peak upload applies jitter and short transactions
- **WHEN** `AttachmentUploadBackgroundService` enters the off-peak window
- **THEN** the worker SHALL apply random jitter within `0..MaxJitterMinutes` before uploading the first batch of that window
- **AND** SHALL query pending attachments in a short read transaction, perform HTTP uploads outside any database transaction, and persist each uploaded attachment's sync status in its own short write transaction

#### Scenario: HTTP 429 or 401 pauses the current upload round gracefully
- **WHEN** `POST /api/File/UploadAttachment` responds with HTTP `429 Too Many Requests` or `401 Unauthorized`
- **THEN** the client SHALL log a warning, immediately stop the current upload batch without throwing unhandled exceptions, and leave remaining pending attachments for subsequent rounds

