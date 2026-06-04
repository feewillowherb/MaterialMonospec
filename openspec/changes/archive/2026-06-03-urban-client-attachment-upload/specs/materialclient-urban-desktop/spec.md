## ADDED Requirements

### Requirement: Urban cloud sync includes attachment upload

MaterialClient.Urban periodic upload (`PollingBackgroundService` → `IUrbanServerUploadService.SubmitRecordAsync`) SHALL synchronize weighing record attachments to UrbanManagement as part of the same pending-upload pipeline, not only weighing metadata fields.

#### Scenario: Pending record upload after weighing completes

- **WHEN** a weighing record is created in UrbanMode with `UrbanPhoto` and `Lrp` attachments and `UrbanWeighingExtension.SyncStatus` is `Pending`
- **AND** `PollingBackgroundService` processes the record
- **THEN** `SubmitRecordAsync` SHALL upload attachment images to UrbanManagement before marking the extension as synced
- **AND** the server-side record SHALL be linkable to those attachments via `attachmentIds` on receive

#### Scenario: UI preview does not imply cloud sync

- **WHEN** the user views LRP or camera photos in `UrbanAttendedWeighingViewModel` from local storage
- **THEN** local preview SHALL continue to use local `AttachmentFile` paths
- **AND** cloud availability SHALL depend on successful background attachment upload, not on UI display alone
