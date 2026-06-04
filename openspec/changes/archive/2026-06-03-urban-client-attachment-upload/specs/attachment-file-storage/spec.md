## ADDED Requirements

### Requirement: FilesPhysicalPath resolves under service content root

UrbanManagement SHALL resolve `StorageOptions.FilesPhysicalPath` relative to the application content root (service run directory), not the client machine. When `FilesPhysicalPath` is `"Uploads/"`, persisted files SHALL be stored under `{ContentRoot}/Uploads/` (or equivalent base-directory combination used by `FileService`).

#### Scenario: Default Uploads folder at startup

- **WHEN** the service starts with `"FilesPhysicalPath": "Uploads/"` and content root `C:\Services\UrbanManagement`
- **THEN** the effective storage root SHALL be `C:\Services\UrbanManagement\Uploads\` (normalized path separators)
- **AND** `FileService` SHALL create the directory if missing or log a clear error if not writable

#### Scenario: Relative path stored in AttachmentFile

- **WHEN** an image is saved via `SaveAndCompressImagesAsync`
- **THEN** `AttachmentFile.LocalPath` SHALL be stored relative to the resolved `FilesPhysicalPath` root
- **AND** `ReadAttachmentFilesAsync` SHALL resolve the same root when loading files for government sync

### Requirement: MaterialClient.Urban attachment upload API

UrbanManagement SHALL expose an HTTP API callable by MaterialClient.Urban that accepts Base64-encoded images and `attachType` (`Lrp` or `UrbanPhoto`), persists files under `{FilesPhysicalPath}/TempUpload/{buildLicenseNo}/`, applies compression per existing rules, creates `AttachmentFile` entities, and returns the created Guid identifiers.

#### Scenario: Successful batch upload

- **WHEN** MaterialClient.Urban sends a valid request with `buildLicenseNo`, `attachType: "Lrp"`, and one or more Base64 JPEG images
- **THEN** the server SHALL invoke `IFileService.SaveAndCompressImagesAsync`
- **AND** SHALL return HTTP 200 with a list of created `AttachmentFile` Guid values
- **AND** files SHALL exist on disk under the resolved `Uploads` root

#### Scenario: Invalid attach type rejected

- **WHEN** the request specifies an attach type other than `Lrp` or `UrbanPhoto`
- **THEN** the server SHALL return HTTP 400 and SHALL NOT create `AttachmentFile` records
