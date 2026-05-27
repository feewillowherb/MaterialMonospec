## MODIFIED Requirements

### Requirement: Save captured photos as attachments

WeighingRecordService SHALL save captured photo paths as `AttachmentFile` entities linked to the `WeighingRecord` via `WeighingRecordAttachment`, using relative paths for database portability. When `WeighingMode` is UrbanMode (201), captured Hikvision photos SHALL use `AttachType.UrbanPhoto`; otherwise SHALL use `AttachType.UnmatchedEntryPhoto`. When UrbanMode and the current weighing cycle has a non-empty LRP image relative path, SHALL additionally create an `AttachmentFile` with `AttachType.Lrp` for that path.

#### Scenario: Photos saved as attachments (non-Urban)
- **WHEN** WeighingMode != UrbanMode (201) and 2 photo paths are provided for weighing record ID 42
- **THEN** SHALL create 2 `AttachmentFile` entries with `AttachType.UnmatchedEntryPhoto` and 2 `WeighingRecordAttachment` link entries, converting to relative paths

#### Scenario: Urban photos saved as UrbanPhoto
- **WHEN** WeighingMode = UrbanMode (201) and 2 Hikvision capture paths are provided for weighing record ID 42
- **THEN** SHALL create 2 `AttachmentFile` entries with `AttachType.UrbanPhoto`
- **AND** SHALL create 2 `WeighingRecordAttachment` link entries

#### Scenario: Urban Lrp linked on record creation
- **WHEN** WeighingMode = UrbanMode (201), a weighing record is created, and the current cycle has LRP relative path `Lrp/京A12345_20260526.jpg`
- **THEN** SHALL create 1 `AttachmentFile` with `AttachType.Lrp` and link it to the weighing record
- **AND** SHALL store the relative path in `LocalPath`

#### Scenario: Photo file does not exist
- **WHEN** a photo path in the list does not exist on disk
- **THEN** SHALL skip that photo and log warning, continue with remaining photos
