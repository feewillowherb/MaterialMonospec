## ADDED Requirements

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
