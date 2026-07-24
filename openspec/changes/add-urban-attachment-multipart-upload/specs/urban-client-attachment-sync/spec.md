## ADDED Requirements

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

## MODIFIED Requirements

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
