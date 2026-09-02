## ADDED Requirements

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
