## MODIFIED Requirements

### Requirement: Save captured photos to application directory

WeighingCaptureService SHALL save captured photos using `AttachmentPathUtils.GetLocalStorageAbsolutePath()` to ensure photos are stored in the application directory regardless of working directory. When `WeighingMode` is UrbanMode (201), SHALL use `AttachType.UrbanPhoto` for the storage path; otherwise SHALL use `AttachType.EntryPhoto` (existing monitoring photo layout).

#### Scenario: Photos saved to correct path
- **WHEN** capture is triggered from any working directory (e.g., C:\Windows\System32)
- **THEN** photos SHALL be saved under the application's attachment storage path for the resolved `AttachType`

#### Scenario: UrbanMode uses UrbanPhoto storage path
- **WHEN** `GetWeighingModeAsync` returns UrbanMode (201) and batch capture runs
- **THEN** SHALL call `GetLocalStorageAbsolutePath(AttachType.UrbanPhoto, ...)`
- **AND** saved files SHALL reside under the `PhotoUrban` dated directory tree
