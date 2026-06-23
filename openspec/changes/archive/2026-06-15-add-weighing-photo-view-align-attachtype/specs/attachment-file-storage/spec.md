## MODIFIED Requirements

### Requirement: AttachmentFile entity for image storage

The system SHALL provide an `AttachmentFile` entity with fields: `Id` (Guid PK), `FileName` (string, max 200), `LocalPath` (string, max 1000), `AttachType` (`AttachType` enum, `short` underlying type, full definition aligned with `MaterialClient.Common.Entities.Enums.AttachType`: `UnmatchedEntryPhoto = 0`, `EntryPhoto = 1`, `ExitPhoto = 2`, `TicketPhoto = 3`, `Lrp = 5`, `UrbanPhoto = 6`), and `AddTime` (DateTime). The entity SHALL map to the `AttachmentFile` database table.

#### Scenario: AttachmentFile entity creation

- **WHEN** an image is saved to disk during legacy or new client processing
- **THEN** the system SHALL create an `AttachmentFile` record with the file name, relative local path, appropriate `AttachType` enum value, and current timestamp

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

### Requirement: MaterialClient.Urban attachment upload API

UrbanManagement SHALL expose an HTTP API callable by MaterialClient.Urban that accepts Base64-encoded images and `attachType` as the `AttachType` enum integer (`5` for Lrp, `6` for UrbanPhoto), persists files under `{FilesPhysicalPath}/{buildLicenseNo}/`, applies compression per existing rules, creates `AttachmentFile` entities with enum `AttachType`, and returns the created Guid identifiers.

#### Scenario: Successful batch upload with Lrp enum

- **WHEN** MaterialClient.Urban sends a valid request with `buildLicenseNo`, `attachType: 5` (Lrp), and one or more Base64 JPEG images
- **THEN** the server SHALL invoke `IFileService.SaveAndCompressImagesAsync` with `AttachType.Lrp`
- **AND** SHALL return HTTP 200 with a list of created `AttachmentFile` Guid values
- **AND** persisted `AttachmentFile.AttachType` SHALL be `5`

#### Scenario: Successful batch upload with UrbanPhoto enum

- **WHEN** MaterialClient.Urban sends `attachType: 6` (UrbanPhoto)
- **THEN** the server SHALL persist attachments with `AttachType.UrbanPhoto` (6)

#### Scenario: Invalid attach type rejected

- **WHEN** the request specifies an attach type other than `5` or `6`
- **THEN** the server SHALL return HTTP 400 and SHALL NOT create `AttachmentFile` records

## ADDED Requirements

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
