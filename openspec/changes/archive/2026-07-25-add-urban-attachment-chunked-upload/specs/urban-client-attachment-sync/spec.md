## ADDED Requirements

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
