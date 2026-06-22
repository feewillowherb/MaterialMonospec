## MODIFIED Requirements

### Requirement: Approval image replacement API on server

`UrbanWeighingRecordAppService.ApproveAsync` SHALL accept an optional `LrpReplacementBase64` field and an optional `AdoptUrbanPhotoAsLpr` boolean on `UrbanWeighingRecordApproveInputDto`. When `LrpReplacementBase64` is non-null and non-empty, the system SHALL replace the Lrp attachment for the record being approved. When `AdoptUrbanPhotoAsLpr` is `true`, the system SHALL copy the existing UrbanPhoto attachment into a new Lrp attachment (see `lpr-adoption-from-urban-photo` capability). UrbanPhoto replacement SHALL NOT be accepted: any legacy `UrbanPhotoReplacementBase64` field SHALL be ignored or rejected, and the server SHALL NOT delete or replace `AttachType.UrbanPhoto` attachments during approval.

#### Scenario: Lrp replacement provided

- **WHEN** `ApproveAsync` is called with `LrpReplacementBase64` that is non-null and non-empty
- **THEN** the system SHALL call `IFileService.ReplaceAttachmentAsync` with `recordId`, `AttachType.Lrp`, and the Base64 string
- **AND** existing `AttachmentFile` and `UrbanWeighingRecordAttachment` rows for that record with `AttachType.Lrp` SHALL be deleted
- **AND** the old Lrp image file on disk SHALL be deleted
- **AND** a new `AttachmentFile` SHALL be created with the decoded image saved to disk
- **AND** a new `UrbanWeighingRecordAttachment` SHALL link the new `AttachmentFile` to the record

#### Scenario: Lrp replacement within same UnitOfWork as approval

- **WHEN** Lrp image replacement and record update both occur during approval
- **THEN** all database changes (Lrp attachment deletion, Lrp attachment creation, record update, edit history append) SHALL participate in the same UnitOfWork
- **AND** a failure in replacement SHALL roll back the entire approval transaction

#### Scenario: No replacement or adoption provided

- **WHEN** `ApproveAsync` is called with `LrpReplacementBase64` null or empty AND `AdoptUrbanPhotoAsLpr` false
- **THEN** the system SHALL NOT modify any attachments
- **AND** existing attachment rows and files SHALL remain unchanged

#### Scenario: UrbanPhoto replacement is rejected

- **WHEN** `ApproveAsync` receives a request that attempts to supply an UrbanPhoto replacement payload (legacy field or any equivalent signal)
- **THEN** the system SHALL NOT delete or create any `AttachType.UrbanPhoto` attachments
- **AND** the existing UrbanPhoto attachment SHALL remain unchanged
- **AND** the system SHALL treat the request as if no UrbanPhoto replacement was supplied

---

### Requirement: Client-side image replacement in approval dialog

The `WeighingRecordEditDialog` in MaterialClient.Urban SHALL allow the operator to replace the Lrp image by selecting a local image file during the approval editing process. The UrbanPhoto section SHALL NOT expose a replace button or any image-replacement control; UrbanPhoto SHALL be display-only.

#### Scenario: Replace Lrp image via file picker

- **WHEN** the operator clicks the replace button on the Lrp photo preview area
- **THEN** the system SHALL open a native file picker dialog filtered to image files (JPEG, PNG, BMP)
- **AND** upon file selection, the system SHALL read the file and convert it to Base64
- **AND** the Lrp preview SHALL update to show the selected image
- **AND** the replacement Base64 SHALL be stored in the dialog result for submission

#### Scenario: UrbanPhoto has no replace affordance

- **WHEN** the approval edit dialog renders the UrbanPhoto preview section
- **THEN** the UrbanPhoto section SHALL NOT display a 替换 button
- **AND** no command or interaction SHALL allow the operator to supply an UrbanPhoto replacement

#### Scenario: Cancel Lrp file selection

- **WHEN** the operator dismisses the Lrp file picker without selecting a file
- **THEN** the original Lrp photo preview SHALL remain unchanged
- **AND** no replacement Base64 SHALL be stored

#### Scenario: Replace Lrp image when original is empty

- **WHEN** the operator clicks the replace button on the Lrp photo area that has no original image (placeholder shown)
- **THEN** the system SHALL open the file picker and allow replacement
- **AND** the preview SHALL update from placeholder to the selected image

#### Scenario: Replace Lrp image and then replace again

- **WHEN** the operator replaces the Lrp image and then clicks the replace button again
- **THEN** the system SHALL allow a second replacement
- **AND** the preview SHALL update to the most recently selected image
- **AND** only the final replacement Base64 SHALL be submitted

---

### Requirement: EditResult carries Lrp replacement data

The `WeighingRecordEditDialogViewModel.EditResult` record SHALL carry an optional `LrpReplacementBase64` field and an `AdoptedLpr` boolean field for transmission to the approval flow. `EditResult` SHALL NOT carry any UrbanPhoto replacement payload.

#### Scenario: EditResult with Lrp replacement

- **WHEN** the operator confirms the approval dialog after replacing the Lrp image
- **THEN** `EditResult.LrpReplacementBase64` SHALL contain the replacement Base64
- **AND** `EditResult.AdoptedLpr` SHALL be `false`

#### Scenario: EditResult with adoption staged

- **WHEN** the operator confirms the approval dialog after triggering the adopt-UrbanPhoto-as-Lpr action
- **THEN** `EditResult.AdoptedLpr` SHALL be `true`
- **AND** `EditResult.LrpReplacementBase64` SHALL be null (adoption and explicit replacement are mutually exclusive)

#### Scenario: EditResult without image changes

- **WHEN** the operator confirms the approval dialog without replacing Lrp or staging adoption
- **THEN** `EditResult.LrpReplacementBase64` SHALL be null
- **AND** `EditResult.AdoptedLpr` SHALL be `false`

---

### Requirement: Client passes replacement or adoption data to server approval call

`UrbanAttendedWeighingViewModel` SHALL extract `LrpReplacementBase64` and `AdoptedLpr` from the `EditResult` and pass them to the server approval call. The ViewModel SHALL NOT send any UrbanPhoto replacement payload.

#### Scenario: Approval with Lrp replacement

- **WHEN** `ApproveRecordAsync` processes an `EditResult` with non-null `LrpReplacementBase64`
- **THEN** the ViewModel SHALL include `LrpReplacementBase64` in the server approval request
- **AND** SHALL set `AdoptUrbanPhotoAsLpr = false`

#### Scenario: Approval with adoption

- **WHEN** `ApproveRecordAsync` processes an `EditResult` with `AdoptedLpr == true`
- **THEN** the ViewModel SHALL set `AdoptUrbanPhotoAsLpr = true` in the server approval request
- **AND** SHALL NOT send an `LrpReplacementBase64` payload

#### Scenario: Approval without image changes

- **WHEN** `ApproveRecordAsync` processes an `EditResult` with null `LrpReplacementBase64` and `AdoptedLpr == false`
- **THEN** the ViewModel SHALL submit the approval request without replacement or adoption data
- **AND** the server SHALL proceed with normal approval (no attachment changes)
