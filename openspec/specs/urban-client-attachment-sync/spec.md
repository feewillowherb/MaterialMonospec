# Urban Client Attachment Sync

## Purpose

Defines MaterialClient.Urban behavior for uploading local LRP and UrbanPhoto attachments to UrbanManagement before weighing record receive, including path normalization, failure semantics, and Refit API integration.
## Requirements
### Requirement: Upload local attachments before weighing record receive

When `IUrbanServerUploadService.SubmitRecordAsync` runs for a weighing record with `SyncStatus == Pending`, MaterialClient.Urban SHALL upload all associated local attachment files of types `Lrp` and `UrbanPhoto` to UrbanManagement before or as part of the same upload transaction, and SHALL pass the returned server `AttachmentFile` Guid values in `UrbanWeighingRecordSubmitDto.AttachmentIds` when calling `ReceiveWeighingRecordAsync`. The default upload transport SHALL be multipart binary (`multipart/form-data`); Base64 JSON upload remains available on the server and as retained client code but is not the default path.

#### Scenario: Record with LRP and UrbanPhoto uploads then receive

- **WHEN** a pending weighing record has one `Lrp` and two `UrbanPhoto` attachments with valid on-disk files
- **THEN** the client SHALL call the UrbanManagement multipart attachment upload API for each attach type (or batch) with binary image file content
- **AND** SHALL collect all returned Guid values
- **AND** SHALL call `ReceiveWeighingRecordAsync` with `attachmentIds` containing those Guids
- **AND** SHALL NOT send `attachmentIds: null` when local attachments exist and upload succeeded

#### Scenario: Record with no attachments

- **WHEN** a pending weighing record has no linked `Lrp` or `UrbanPhoto` attachments
- **THEN** the client MAY call `ReceiveWeighingRecordAsync` with `attachmentIds` omitted or null
- **AND** SHALL still upload weighing metadata as today

#### Scenario: Local file missing for one attachment

- **WHEN** an attachment row exists but the normalized local path does not exist on disk
- **THEN** the client SHALL log a warning and skip that file
- **AND** SHALL continue uploading remaining attachments
- **AND** if at least one attachment uploaded successfully, SHALL include successful Guids in `attachmentIds`

### Requirement: Normalize attachment paths before file read

MaterialClient.Urban SHALL normalize `AttachmentFile.LocalPath` to an absolute path based on the application directory before `File.Exists` or read operations during upload, consistent with `file-api-relative-path-normalization`.

#### Scenario: Relative path under wrong working directory

- **WHEN** `LocalPath` is stored as a relative path and the process working directory is not the application directory
- **THEN** the upload logic SHALL resolve the path against the application base directory
- **AND** SHALL read the correct file when it exists under the application storage layout

### Requirement: Attachment upload failure retains pending sync

When attachment upload or subsequent `ReceiveWeighingRecordAsync` fails, MaterialClient.Urban SHALL NOT mark the `UrbanWeighingExtension` as `Synced` for that record.

#### Scenario: Upload API returns error

- **WHEN** UrbanManagement attachment upload returns a non-success HTTP status
- **THEN** the client SHALL log the error
- **AND** SHALL leave `SyncStatus` as `Pending` for retry on the next poll

#### Scenario: Receive succeeds but attachment upload partially failed with policy abort

- **WHEN** the implementation policy requires all local attachments to upload successfully and any required attachment failed
- **THEN** the client SHALL NOT call `ReceiveWeighingRecordAsync` (or SHALL treat the operation as failed)
- **AND** SHALL leave `SyncStatus` as `Pending`

### Requirement: Refit client for attachment upload

MaterialClient.Urban SHALL extend `IUrbanManagementApi` and/or a dedicated Refit interface registered in `MaterialClientUrbanModule` with a method that calls the UrbanManagement multipart attachment upload endpoint using the same `UrbanManagement:BaseUrl` configuration as weighing record receive. Interface-level forced `Content-Type: application/json` MUST NOT apply to the multipart method. The legacy JSON Base64 upload Refit method SHALL remain registered or defined for compatibility and MUST NOT be deleted in this change.

#### Scenario: API registration at startup

- **WHEN** `MaterialClientUrbanModule` configures Refit clients
- **THEN** the multipart attachment upload client SHALL be registered with base address `UrbanManagement:BaseUrl`
- **AND** SHALL be able to send `multipart/form-data` without a fixed `application/json` content type on that request

#### Scenario: Legacy JSON upload method still present

- **WHEN** Refit API definitions for UrbanManagement are compiled
- **THEN** the previous Base64 JSON upload method SHALL still be present in source
- **AND** JSON receive and other non-file endpoints SHALL continue to use JSON content types as required

### Requirement: Upload Lrp created during client approval on next pending sync

When MaterialClient.Urban approval creates or replaces a local `AttachType.Lrp` attachment (including adopt from UrbanPhoto) and resets `SyncStatus` to `Pending`, the next successful `SubmitRecordAsync` for that record—triggered by `UrbanWeighingUploadRequestedEventData` (immediate) or `PollingBackgroundService` (fallback)—SHALL upload the new or updated Lrp file to UrbanManagement via the default multipart upload path and include its server Guid in `UrbanWeighingRecordSubmitDto.AttachmentIds`.

#### Scenario: Adopt creates Lrp then approval triggers upload

- **WHEN** the operator adopts UrbanPhoto as Lrp locally during approval and confirms Save
- **AND** `UpdateWeighingRecordAsync` sets `SyncStatus` to `Pending`
- **AND** `UrbanWeighingUploadRequestedEventData` is handled (or `PollingBackgroundService` runs as fallback)
- **THEN** the client SHALL upload the newly created local Lrp file via the multipart attachment upload API with `attachType` Lrp
- **AND** SHALL include the returned Guid in `attachmentIds` when calling `ReceiveWeighingRecordAsync`
- **AND** SHALL also upload any existing UrbanPhoto attachments per existing rules

#### Scenario: Re-upload after adopt replaces missing server Lrp

- **WHEN** the server record previously had no Lrp attachment but had UrbanPhoto
- **AND** client approval adopt created a local Lrp and sync completed successfully
- **THEN** UrbanManagement SHALL associate the uploaded Lrp Guid with the server record via `ReceiveAsync` attachment linking
- **AND** the server UrbanPhoto attachment SHALL remain unchanged

#### Scenario: Upload failure retains pending after adopt

- **WHEN** local Lrp was created during approval but attachment upload fails on immediate handler or next poll
- **THEN** `SyncStatus` SHALL remain `Pending` for retry
- **AND** the local Lrp attachment SHALL remain on disk for subsequent upload attempts

### Requirement: Prefer multipart upload while retaining Base64 client code

MaterialClient.Urban SHALL use the UrbanManagement multipart binary attachment upload API as the default upload path in `IUrbanAttachmentSyncService` / `SubmitRecordAsync` flow. The existing Base64 JSON Refit upload method and related DTO types SHALL remain in the codebase (not deleted) for rollback and legacy reference until a future remove change deletes them after all clients are upgraded.

#### Scenario: Default sync uses multipart

- **WHEN** `UploadAttachmentsAsync` runs for a pending record with on-disk Lrp or UrbanPhoto files
- **THEN** the client SHALL send `multipart/form-data` with binary file parts (not Base64 JSON) to the multipart upload endpoint
- **AND** SHALL collect returned Guid values for `ReceiveWeighingRecordAsync`

#### Scenario: Base64 Refit method retained

- **WHEN** the MaterialClient.Urban source is inspected after this change
- **THEN** the previous JSON Base64 upload Refit method (and request DTO capable of carrying Base64 `images`) SHALL still exist in source
- **AND** the default sync path SHALL NOT call it unless explicitly switched for rollback

### Requirement: Settings switch selects tus or multipart attachment upload

MaterialClient.Urban SHALL read a persisted system setting that enables or disables tus-based chunked attachment upload. When the setting is disabled (default), the client SHALL use the existing multipart binary upload path. When enabled, the client SHALL upload each Lrp/UrbanPhoto file via the UrbanManagement tusdotnet endpoint (create + PATCH chunks + complete), then obtain `AttachmentFile` Guid values through the server thin attachment-id/commit API before `ReceiveWeighingRecordAsync`.

#### Scenario: Default uses multipart

- **WHEN** `EnableChunkedAttachmentUpload` is false or unset
- **AND** `UploadAttachmentsAsync` runs for a pending record with on-disk Lrp or UrbanPhoto files
- **THEN** the client SHALL upload via the multipart endpoint
- **AND** SHALL NOT create tus uploads

#### Scenario: Enabled uses tus protocol

- **WHEN** `EnableChunkedAttachmentUpload` is true
- **AND** `UploadAttachmentsAsync` runs for a pending record with on-disk attachment files
- **THEN** the client SHALL perform tus uploads with metadata `buildlicenseno` and `attachtype`
- **AND** SHALL obtain returned Guid values for `ReceiveWeighingRecordAsync`

#### Scenario: tus upload failure retains pending

- **WHEN** tus upload is enabled and create, patch, complete, or attachment-id retrieval fails
- **THEN** the client SHALL log the error
- **AND** SHALL leave `SyncStatus` as `Pending` for retry
- **AND** SHALL NOT mark the record as `Synced`

### Requirement: tus client adapter separate from Refit JSON/multipart methods

MaterialClient.Urban SHALL implement tus protocol uploads using a dedicated HTTP/tus client adapter (community .NET tus library or thin `HttpClient` helper). The existing multipart and Base64 Refit methods on `IUrbanManagementApi` SHALL remain in source. Refit MAY be used only for the thin post-tus attachment-id/commit JSON API and for Receive/other JSON endpoints, not as the primary expression of tus PATCH semantics.

#### Scenario: Multipart and Base64 Refit methods retained

- **WHEN** UrbanManagement Refit API definitions are compiled after this change
- **THEN** the multipart upload method and Base64 JSON upload method SHALL still exist in source

#### Scenario: tus path does not force application/json on PATCH

- **WHEN** chunked upload mode uploads a file slice via tus PATCH
- **THEN** the request SHALL use tus-required headers and a binary body with definite length semantics
- **AND** SHALL NOT send a forced `Content-Type: application/json` for that PATCH

### Requirement: Upload passage attachments before passage ingest

When MaterialClient.Urban submits a pending passage record, it SHALL upload associated local capture files via the existing UrbanManagement multipart attachment API and SHALL pass returned Guids on the checkpoint or finished-product ingest DTO. Missing files MUST be skipped with a warning without blocking remaining files.

#### Scenario: Passage with large photo uploads then ingest

- **WHEN** a pending checkpoint passage has a readable large capture file
- **THEN** the client SHALL multipart-upload that file
- **AND** SHALL include the returned Guid on checkpoint ingest
- **AND** SHALL NOT send Xiaoshan Base64 `snapImages` from the client

### Requirement: Upload passage attachments by attachment id

`IUrbanAttachmentSyncService` SHALL support uploading files linked on a passage row by local `AttachmentFile` id (large and optional small capture). The default transport MUST remain multipart binary. Missing local files MUST log a warning and skip that file without aborting other files or the ingest call.

#### Scenario: Large capture upload before ingest

- **WHEN** a pending passage row has `LargeImageAttachmentId` pointing to a readable local file
- **THEN** the client SHALL multipart-upload that file before passage receive
- **AND** SHALL pass returned server Guids on the passage submit DTO

#### Scenario: No attachment still ingests metadata

- **WHEN** a pending passage row has no readable attachment files
- **THEN** the client SHALL still call passage receive with metadata fields
- **AND** `attachmentIds` MAY be null or empty

