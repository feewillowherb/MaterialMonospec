## ADDED Requirements

### Requirement: IFileService AdoptUrbanPhotoAsLprAsync method

`IFileService` SHALL provide an `AdoptUrbanPhotoAsLprAsync(Guid recordId)` method that copies the existing UrbanPhoto attachment for the given record into a new `AttachType.Lrp` attachment, leaving the original UrbanPhoto attachment untouched.

#### Scenario: Adopt when UrbanPhoto exists and Lrp is absent

- **WHEN** `AdoptUrbanPhotoAsLprAsync(recordId)` is called for a record that has exactly one `AttachType.UrbanPhoto` attachment with a non-empty `LocalPath`
- **AND** the record has no existing `AttachType.Lrp` attachment
- **THEN** the method SHALL read the UrbanPhoto source file from disk
- **AND** SHALL create a new `AttachmentFile` of `AttachType.Lrp` whose stored image is a copy of the UrbanPhoto source
- **AND** SHALL create a new `UrbanWeighingRecordAttachment` linking the new Lrp `AttachmentFile` to the record
- **AND** SHALL NOT delete or modify the existing UrbanPhoto `AttachmentFile` or its junction row
- **AND** SHALL return the `Guid` of the newly created Lrp `AttachmentFile`

#### Scenario: Adopt when UrbanPhoto exists and Lrp already present

- **WHEN** `AdoptUrbanPhotoAsLprAsync(recordId)` is called for a record that already has an `AttachType.Lrp` attachment
- **THEN** the method SHALL reject the call with a clear business error
- **AND** SHALL NOT create any new attachment
- **AND** SHALL NOT modify the existing Lrp or UrbanPhoto attachments

#### Scenario: Adopt when UrbanPhoto is absent

- **WHEN** `AdoptUrbanPhotoAsLprAsync(recordId)` is called for a record that has no `AttachType.UrbanPhoto` attachment
- **THEN** the method SHALL reject the call with a clear business error
- **AND** SHALL NOT create any new attachment

#### Scenario: Adoption is idempotent within a single UnitOfWork

- **WHEN** `AdoptUrbanPhotoAsLprAsync(recordId)` participates in the same UnitOfWork as the approval record update
- **THEN** any failure during file copy or attachment insertion SHALL roll back the entire approval transaction
- **AND** no partial Lrp attachment SHALL be persisted

#### Scenario: Original UrbanPhoto file remains on disk

- **WHEN** `AdoptUrbanPhotoAsLprAsync(recordId)` completes successfully
- **THEN** the UrbanPhoto source file at its original `LocalPath` SHALL remain on disk
- **AND** the UrbanPhoto `AttachmentFile.LocalPath` SHALL remain unchanged

---

### Requirement: ApproveAsync orchestrates Lpr adoption transactionally

`UrbanWeighingRecordAppService.ApproveAsync` SHALL invoke `IFileService.AdoptUrbanPhotoAsLprAsync(recordId)` when the approval input has `AdoptUrbanPhotoAsLpr == true`, within the same UnitOfWork as the record update and edit-history append.

#### Scenario: Adoption input triggers AdoptUrbanPhotoAsLprAsync

- **WHEN** `ApproveAsync` is called with `AdoptUrbanPhotoAsLpr == true` and `LrpReplacementBase64` null or empty
- **THEN** the system SHALL call `IFileService.AdoptUrbanPhotoAsLprAsync(recordId)`
- **AND** SHALL NOT call `IFileService.ReplaceAttachmentAsync`
- **AND** SHALL append an `EditEntry` with `IsLprAdoptedFromUrbanPhoto = true`

#### Scenario: Adoption and explicit Lrp replacement are mutually exclusive

- **WHEN** `ApproveAsync` is called with both `AdoptUrbanPhotoAsLpr == true` AND `LrpReplacementBase64` non-empty
- **THEN** the system SHALL reject the request with a validation error
- **OR** the system SHALL prioritize `LrpReplacementBase64` and SHALL NOT invoke adoption
- **AND** SHALL NOT perform both operations in the same approval

#### Scenario: Adoption only valid when Lpr is currently empty

- **WHEN** `ApproveAsync` is called with `AdoptUrbanPhotoAsLpr == true`
- **AND** the record currently has an existing `AttachType.Lrp` attachment
- **THEN** the system SHALL reject the request with a business validation error
- **AND** SHALL NOT modify any attachment

#### Scenario: Adoption requires an existing UrbanPhoto

- **WHEN** `ApproveAsync` is called with `AdoptUrbanPhotoAsLpr == true`
- **AND** the record has no `AttachType.UrbanPhoto` attachment
- **THEN** the system SHALL reject the request with a business validation error
- **AND** SHALL NOT modify any attachment

---

### Requirement: Client exposes adopt-as-Lpr command

The `WeighingRecordEditDialogViewModel` in MaterialClient.Urban SHALL expose an `AdoptUrbanPhotoAsLprCommand` that stages an adoption in the dialog result. The command SHALL only be invokable when `LprPhotoPath` is null or empty AND `CameraPhotoPath` is non-empty.

#### Scenario: Adopt command enabled when precondition met

- **WHEN** the dialog loads with `LprPhotoPath` null or empty AND `CameraPhotoPath` non-empty
- **THEN** `AdoptUrbanPhotoAsLprCommand` SHALL be enabled
- **AND** the「采纳为车牌照」button SHALL be visible

#### Scenario: Adopt command disabled when Lpr present

- **WHEN** the dialog loads with `LprPhotoPath` non-empty
- **THEN** `AdoptUrbanPhotoAsLprCommand` SHALL be disabled
- **AND** the「采纳为车牌照」button SHALL be hidden

#### Scenario: Adopt command disabled when UrbanPhoto absent

- **WHEN** the dialog loads with `CameraPhotoPath` null or empty
- **THEN** `AdoptUrbanPhotoAsLprCommand` SHALL be disabled
- **AND** the「采纳为车牌照」button SHALL be hidden

#### Scenario: Invoking adopt stages result and updates Lpr preview

- **WHEN** the operator activates `AdoptUrbanPhotoAsLprCommand`
- **THEN** the ViewModel SHALL set `EditResult.AdoptedLpr = true`
- **AND** SHALL set `EditResult.LrpReplacementBase64 = null`
- **AND** the Lrp preview SHALL update to show the UrbanPhoto source image
- **AND** the 抓拍异常 warning SHALL be cleared from the Lrp section

#### Scenario: Adopt then cancel restores empty Lpr state

- **WHEN** the operator activates `AdoptUrbanPhotoAsLprCommand` and then activates a "取消采纳" affordance (or otherwise unsets the staged adoption)
- **THEN** `EditResult.AdoptedLpr` SHALL revert to `false`
- **AND** the Lrp preview SHALL return to the placeholder plus 抓拍异常 warning
