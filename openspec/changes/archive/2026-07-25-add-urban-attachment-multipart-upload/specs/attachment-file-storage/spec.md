## ADDED Requirements

### Requirement: Multipart binary attachment upload API

UrbanManagement SHALL expose an HTTP API callable by MaterialClient.Urban that accepts `multipart/form-data` with form fields `buildLicenseNo`, `attachType` (`AttachType` enum integer `5` for Lrp or `6` for UrbanPhoto), and one or more binary image file parts, persists files under `{FilesPhysicalPath}/{buildLicenseNo}/`, applies compression per existing rules, creates `AttachmentFile` entities with enum `AttachType`, and returns the created Guid identifiers in the same response shape as the Base64 upload API (`attachmentIds`).

#### Scenario: Successful multipart batch with Lrp

- **WHEN** MaterialClient.Urban sends a valid multipart request with `buildLicenseNo`, `attachType: 5` (Lrp), and one or more JPEG (or other supported image) file parts
- **THEN** the server SHALL persist attachments via the shared file-save path used by Base64 upload (byte-array save and compress)
- **AND** SHALL return HTTP 200 with a list of created `AttachmentFile` Guid values
- **AND** persisted `AttachmentFile.AttachType` SHALL be `5`

#### Scenario: Successful multipart batch with UrbanPhoto

- **WHEN** MaterialClient.Urban sends `attachType: 6` (UrbanPhoto) with binary file parts
- **THEN** the server SHALL persist attachments with `AttachType.UrbanPhoto` (6)

#### Scenario: Multipart invalid attach type rejected

- **WHEN** the multipart request specifies an attach type other than `5` or `6`
- **THEN** the server SHALL return HTTP 400 and SHALL NOT create `AttachmentFile` records

#### Scenario: Multipart missing buildLicenseNo rejected

- **WHEN** `buildLicenseNo` is missing or whitespace-only
- **THEN** the server SHALL return HTTP 400 and SHALL NOT create `AttachmentFile` records

### Requirement: Base64 upload API retained during multipart rollout

UrbanManagement SHALL continue to expose the existing Base64 JSON attachment upload API (`IUrbanAttachmentAppService.UploadAsync` / conventional `POST` under `urban-attachment/upload`) with unchanged request and response contracts while multipart is the preferred client path. Removal of the Base64 upload API SHALL require a separate explicit change after all clients have migrated.

#### Scenario: Legacy Base64 client still uploads

- **WHEN** an older MaterialClient.Urban (or other caller) posts a valid Base64 JSON upload request to the legacy endpoint
- **THEN** the server SHALL save and compress images and return `attachmentIds` as today
- **AND** SHALL NOT require multipart

#### Scenario: Both APIs share persistence rules

- **WHEN** the same image bytes are uploaded once via Base64 and once via multipart with the same `buildLicenseNo` and `attachType`
- **THEN** both paths SHALL apply the same compression threshold and JPEG quality rules
- **AND** both SHALL create `AttachmentFile` rows with relative `LocalPath` under the resolved storage root

## MODIFIED Requirements

### Requirement: MaterialClient.Urban attachment upload API

UrbanManagement SHALL expose an HTTP API callable by MaterialClient.Urban that accepts Base64-encoded images and `attachType` as the `AttachType` enum integer (`5` for Lrp, `6` for UrbanPhoto), persists files under `{FilesPhysicalPath}/{buildLicenseNo}/`, applies compression per existing rules, creates `AttachmentFile` entities with enum `AttachType`, and returns the created Guid identifiers. This Base64 JSON API remains supported for backward compatibility alongside the multipart binary upload API; it is the legacy path and MUST NOT be removed in this change.

#### Scenario: Successful batch upload with Lrp enum

- **WHEN** MaterialClient.Urban sends a valid request with `buildLicenseNo`, `attachType: 5` (Lrp), and one or more Base64 JPEG images
- **THEN** the server SHALL invoke `IFileService.SaveAndCompressImagesAsync` (or the shared byte-array save path it delegates to) with `AttachType.Lrp`
- **AND** SHALL return HTTP 200 with a list of created `AttachmentFile` Guid values
- **AND** persisted `AttachmentFile.AttachType` SHALL be `5`

#### Scenario: Successful batch upload with UrbanPhoto enum

- **WHEN** MaterialClient.Urban sends `attachType: 6` (UrbanPhoto)
- **THEN** the server SHALL persist attachments with `AttachType.UrbanPhoto` (6)

#### Scenario: Invalid attach type rejected

- **WHEN** the request specifies an attach type other than `5` or `6`
- **THEN** the server SHALL return HTTP 400 and SHALL NOT create `AttachmentFile` records
