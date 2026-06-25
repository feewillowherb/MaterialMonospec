# Urban Client Attachment Sync

## Purpose

Defines MaterialClient.Urban behavior for uploading local LRP and UrbanPhoto attachments to UrbanManagement before weighing record receive, including path normalization, failure semantics, and Refit API integration.
## Requirements
### Requirement: Upload local attachments before weighing record receive

When `IUrbanServerUploadService.SubmitRecordAsync` runs for a weighing record with `SyncStatus == Pending`, MaterialClient.Urban SHALL upload all associated local attachment files of types `Lrp` and `UrbanPhoto` to UrbanManagement before or as part of the same upload transaction, and SHALL pass the returned server `AttachmentFile` Guid values in `UrbanWeighingRecordSubmitDto.AttachmentIds` when calling `ReceiveWeighingRecordAsync`.

#### Scenario: Record with LRP and UrbanPhoto uploads then receive

- **WHEN** a pending weighing record has one `Lrp` and two `UrbanPhoto` attachments with valid on-disk files
- **THEN** the client SHALL call the UrbanManagement attachment upload API for each attach type (or batch) with Base64-encoded image content
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

MaterialClient.Urban SHALL extend `IUrbanManagementApi` (or a dedicated Refit interface registered in `MaterialClientUrbanModule`) with a method that calls the UrbanManagement attachment upload endpoint using the same `UrbanManagement:BaseUrl` configuration as weighing record receive.

#### Scenario: API registration at startup

- **WHEN** `MaterialClientUrbanModule` configures Refit clients
- **THEN** the attachment upload client SHALL be registered with base address `UrbanManagement:BaseUrl`
- **AND** SHALL use JSON request/response bodies aligned with the server DTO

### Requirement: Upload Lrp created during client approval on next pending sync

When MaterialClient.Urban approval creates or replaces a local `AttachType.Lrp` attachment (including adopt from UrbanPhoto) and resets `SyncStatus` to `Pending`, the next successful `SubmitRecordAsync` for that record—triggered by `UrbanWeighingUploadRequestedEventData` (immediate) or `PollingBackgroundService` (fallback)—SHALL upload the new or updated Lrp file to UrbanManagement and include its server Guid in `UrbanWeighingRecordSubmitDto.AttachmentIds`.

#### Scenario: Adopt creates Lrp then approval triggers upload

- **WHEN** the operator adopts UrbanPhoto as Lrp locally during approval and confirms Save

- **AND** `UpdateWeighingRecordAsync` sets `SyncStatus` to `Pending`

- **AND** `UrbanWeighingUploadRequestedEventData` is handled (or `PollingBackgroundService` runs as fallback)

- **THEN** the client SHALL upload the newly created local Lrp file via the attachment upload API with `attachType` Lrp

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

