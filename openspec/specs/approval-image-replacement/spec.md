# approval-image-replacement Specification

## Purpose
TBD - created by archiving change approval-image-replacement-capture-anomaly. Update Purpose after archive.
## Requirements
### Requirement: Approval image replacement API on server

`UrbanWeighingRecordAppService.ApproveAsync` SHALL accept optional `LrpReplacementBase64` and `UrbanPhotoReplacementBase64` fields on `UrbanWeighingRecordApproveInputDto`. When either field is non-null and non-empty, the system SHALL replace the corresponding attachment for the record being approved.

#### Scenario: Lrp replacement provided

- **WHEN** `ApproveAsync` is called with `LrpReplacementBase64` that is non-null and non-empty
- **THEN** the system SHALL call `IFileService.ReplaceAttachmentAsync` with `recordId`, `AttachType.Lrp`, and the Base64 string
- **AND** existing `AttachmentFile` and `UrbanWeighingRecordAttachment` rows for that record with `AttachType.Lrp` SHALL be deleted
- **AND** the old image file on disk SHALL be deleted
- **AND** a new `AttachmentFile` SHALL be created with the decoded image saved to disk
- **AND** a new `UrbanWeighingRecordAttachment` SHALL link the new `AttachmentFile` to the record

#### Scenario: UrbanPhoto replacement provided

- **WHEN** `ApproveAsync` is called with `UrbanPhotoReplacementBase64` that is non-null and non-empty
- **THEN** the system SHALL call `IFileService.ReplaceAttachmentAsync` with `recordId`, `AttachType.UrbanPhoto`, and the Base64 string
- **AND** existing `AttachmentFile` and `UrbanWeighingRecordAttachment` rows for that record with `AttachType.UrbanPhoto` SHALL be deleted
- **AND** the old image file on disk SHALL be deleted
- **AND** a new `AttachmentFile` SHALL be created with the decoded image saved to disk
- **AND** a new `UrbanWeighingRecordAttachment` SHALL link the new `AttachmentFile` to the record

#### Scenario: Both replacements provided in single approval

- **WHEN** `ApproveAsync` is called with both `LrpReplacementBase64` and `UrbanPhotoReplacementBase64` non-null and non-empty
- **THEN** the system SHALL replace both attachments within the same approval transaction
- **AND** each replacement SHALL follow the same delete-old-create-new logic independently

#### Scenario: No replacement provided

- **WHEN** `ApproveAsync` is called with both replacement fields null or empty
- **THEN** the system SHALL NOT modify any attachments
- **AND** existing attachment rows and files SHALL remain unchanged

#### Scenario: Replacement within same UnitOfWork as approval

- **WHEN** image replacement and record update both occur during approval
- **THEN** all database changes (attachment deletion, attachment creation, record update, edit history append) SHALL participate in the same UnitOfWork
- **AND** a failure in replacement SHALL roll back the entire approval transaction

---

### Requirement: IFileService ReplaceAttachmentAsync method

`IFileService` SHALL provide a `ReplaceAttachmentAsync(Guid recordId, AttachType attachType, string base64Image)` method that atomically replaces all attachments of a given type for a given record.

#### Scenario: Replace with new image

- **WHEN** `ReplaceAttachmentAsync` is called for a record that has existing attachments of the specified `AttachType`
- **THEN** the method SHALL first save the new image via existing compression logic (`SaveAndCompressImagesAsync`)
- **AND** SHALL create a new `AttachmentFile` record and `UrbanWeighingRecordAttachment` junction record
- **AND** SHALL then delete the old `UrbanWeighingRecordAttachment` and `AttachmentFile` records
- **AND** SHALL attempt to delete the old image file from disk
- **AND** SHALL return the `Guid` of the newly created `AttachmentFile`

#### Scenario: Replace when no existing attachments

- **WHEN** `ReplaceAttachmentAsync` is called for a record that has NO existing attachments of the specified `AttachType`
- **THEN** the method SHALL create a new `AttachmentFile` and junction record with the provided image
- **AND** SHALL NOT throw an error about missing old attachments

#### Scenario: Old file deletion failure does not block

- **WHEN** deleting the old image file from disk fails (e.g. file locked or missing)
- **THEN** the method SHALL log a warning and continue
- **AND** the new attachment SHALL still be persisted
- **AND** the method SHALL NOT throw

---

### Requirement: Client-side image replacement in approval dialog

The `WeighingRecordEditDialog` in MaterialClient.Urban SHALL allow the operator to replace Lrp and UrbanPhoto images by selecting a local image file during the approval editing process.

#### Scenario: Replace Lrp image via file picker

- **WHEN** the operator clicks the replace button on the Lrp photo preview area
- **THEN** the system SHALL open a native file picker dialog filtered to image files (JPEG, PNG, BMP)
- **AND** upon file selection, the system SHALL read the file and convert it to Base64
- **AND** the Lrp preview SHALL update to show the selected image
- **AND** the replacement Base64 SHALL be stored in the dialog result for submission

#### Scenario: Replace UrbanPhoto image via file picker

- **WHEN** the operator clicks the replace button on the UrbanPhoto photo preview area
- **THEN** the system SHALL open a native file picker dialog filtered to image files
- **AND** upon file selection, the system SHALL read the file and convert it to Base64
- **AND** the UrbanPhoto preview SHALL update to show the selected image
- **AND** the replacement Base64 SHALL be stored in the dialog result for submission

#### Scenario: Cancel file selection

- **WHEN** the operator dismisses the file picker without selecting a file
- **THEN** the original photo preview SHALL remain unchanged
- **AND** no replacement Base64 SHALL be stored

#### Scenario: Replace image when original is empty

- **WHEN** the operator clicks the replace button on a photo area that has no original image (placeholder shown)
- **THEN** the system SHALL open the file picker and allow replacement
- **AND** the preview SHALL update from placeholder to the selected image

#### Scenario: Replace image and then replace again

- **WHEN** the operator replaces an image and then clicks the replace button again
- **THEN** the system SHALL allow a second replacement
- **AND** the preview SHALL update to the most recently selected image
- **AND** only the final replacement Base64 SHALL be submitted

---

### Requirement: EditResult carries replacement image data

The `WeighingRecordEditDialogViewModel.EditResult` record SHALL carry optional replacement image Base64 data for transmission to the approval flow.

#### Scenario: EditResult with replacement data

- **WHEN** the operator confirms the approval dialog after replacing one or both images
- **THEN** `EditResult` SHALL contain `LrpReplacementBase64` with the replacement Base64 if Lrp was replaced, otherwise null
- **AND** SHALL contain `UrbanPhotoReplacementBase64` with the replacement Base64 if UrbanPhoto was replaced, otherwise null

#### Scenario: EditResult without replacement

- **WHEN** the operator confirms the approval dialog without replacing any images
- **THEN** both `LrpReplacementBase64` and `UrbanPhotoReplacementBase64` SHALL be null

---

### Requirement: Client passes replacement images to server approval call

`UrbanAttendedWeighingViewModel` SHALL extract replacement image data from the `EditResult` and pass it to the server approval call.

#### Scenario: Approval with replacement images

- **WHEN** `ApproveRecordAsync` processes an `EditResult` with non-null replacement Base64 fields
- **THEN** the ViewModel SHALL include the replacement Base64 data in the server approval request
- **AND** the server SHALL receive and process the replacements as part of the approval

#### Scenario: Approval without replacement images

- **WHEN** `ApproveRecordAsync` processes an `EditResult` with null replacement Base64 fields
- **THEN** the ViewModel SHALL submit the approval request without replacement data
- **AND** the server SHALL proceed with normal approval (no attachment changes)

---

### Requirement: Lrp empty shows capture anomaly hint on client

The MaterialClient.Urban approval edit dialog SHALL display a "抓拍异常" warning when the Lrp photo is empty or missing.

#### Scenario: Lrp empty displays anomaly hint

- **WHEN** the approval edit dialog opens for a record and `LprPhotoPath` is null or empty
- **THEN** the Lrp photo preview area SHALL display the default placeholder image
- **AND** SHALL display "抓拍异常" warning text below or overlaid on the placeholder

#### Scenario: Lrp present hides anomaly hint

- **WHEN** the approval edit dialog opens for a record and `LprPhotoPath` is not null or empty
- **THEN** the "抓拍异常" warning SHALL NOT be displayed

---

### Requirement: Lrp empty shows capture anomaly hint on UrbanManagement Web

The UrbanManagement Web approval photo preview component SHALL display a "抓拍异常" indicator when the Lrp image is null or empty.

#### Scenario: Lrp image empty in Web preview

- **WHEN** `WeighingPhotoPreview` renders with `LrpImageBase64` that is null or empty
- **THEN** the component SHALL display "抓拍异常" text in the Lrp section instead of the generic "暂无图片" placeholder

#### Scenario: Lrp image present in Web preview

- **WHEN** `WeighingPhotoPreview` renders with non-null, non-empty `LrpImageBase64`
- **THEN** the component SHALL display the image normally
- **AND** SHALL NOT display "抓拍异常" text
