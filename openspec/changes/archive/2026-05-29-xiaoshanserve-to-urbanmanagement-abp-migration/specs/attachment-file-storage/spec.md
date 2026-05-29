## ADDED Requirements

### Requirement: AttachmentFile entity for image storage
The system SHALL provide an `AttachmentFile` entity with fields: `Id` (Guid PK), `FileName` (string, max 200), `LocalPath` (string, max 1000), `AttachType` (string, max 50, restricted to `Lrp` and `UrbanPhoto`), and `AddTime` (DateTime). The entity SHALL map to the `AttachmentFile` database table.

#### Scenario: AttachmentFile entity creation
- **WHEN** an image is saved to disk during legacy or new client processing
- **THEN** the system SHALL create an `AttachmentFile` record with the file name, relative local path, appropriate `AttachType`, and current timestamp

### Requirement: UrbanWeighingRecordAttachment join table
The system SHALL provide a `UrbanWeighingRecordAttachment` entity with fields: `Id` (Guid PK), `UrbanWeighingRecordId` (long, FK to UrbanWeighingRecord), `AttachmentFileId` (Guid, FK to AttachmentFile). The entity SHALL map to the `UrbanWeighingRecordAttachment` table with indexes on both foreign keys.

#### Scenario: Associating attachments with a weighing record
- **WHEN** a weighing record is created with associated images
- **THEN** the system SHALL create `UrbanWeighingRecordAttachment` records linking the weighing record to each `AttachmentFile`

### Requirement: Base64 image save and compress
The system SHALL accept an array of Base64-encoded image strings, decode them, save each to local disk at the path `{FilesPhysicalPath}/TempUpload/{buildLicenseNo}/{ticks}_{index}.jpg`, and automatically compress images exceeding the configured `CompressImage` KB threshold using JPEG quality 60.

#### Scenario: Image within size threshold
- **WHEN** a Base64 image decodes to 150 KB and the threshold is 200 KB
- **THEN** the system SHALL save the image without compression and create an `AttachmentFile` record

#### Scenario: Image exceeding size threshold
- **WHEN** a Base64 image decodes to 300 KB and the threshold is 200 KB
- **THEN** the system SHALL compress the image to JPEG quality 60 before saving, and create an `AttachmentFile` record

#### Scenario: Multiple images in one request
- **WHEN** a request contains 3 Base64 images
- **THEN** the system SHALL save all 3 as separate files and create 3 `AttachmentFile` records

### Requirement: Storage configuration via IOptions
The system SHALL bind storage configuration from `appsettings.json` to a `StorageOptions` class via `IOptions<T>`, including: `FilesPhysicalPath` (string, root directory for file storage), `CompressImage` (int, compression threshold in KB, default 200), and `GovAddress` (string, government API endpoint URL).

#### Scenario: Configuration loaded on startup
- **WHEN** the application starts with `appsettings.json` containing `"FilesPhysicalPath": "Uploads/"`, `"CompressImage": 200`, `"GovAddress": ""`
- **THEN** the `StorageOptions` SHALL be available via DI with these values

### Requirement: AttachType restricted to Lrp and UrbanPhoto
The `AttachmentFile.AttachType` field SHALL only accept the values `Lrp` (license plate recognition, value 5) and `UrbanPhoto` (general urban photo, value 6). No other attach types are permitted.

#### Scenario: Lrp attach type
- **WHEN** an image is saved from a license plate recognition event
- **THEN** the `AttachmentFile.AttachType` SHALL be set to `Lrp`

#### Scenario: Invalid attach type
- **WHEN** the system attempts to create an `AttachmentFile` with any `AttachType` other than `Lrp` or `UrbanPhoto`
- **THEN** the system SHALL reject the operation

### Requirement: Attachment reading for sync forwarding
The system SHALL be able to read all `AttachmentFile` records associated with a `UrbanWeighingRecord`, load the image files from disk, and convert them to Base64 strings for forwarding to the government API.

#### Scenario: Reading attachments for forwarding
- **WHEN** the background sync worker processes a record with 2 associated attachments
- **THEN** the system SHALL load both files from disk, convert to Base64, and include them in the government API payload
