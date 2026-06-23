## ADDED Requirements



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


