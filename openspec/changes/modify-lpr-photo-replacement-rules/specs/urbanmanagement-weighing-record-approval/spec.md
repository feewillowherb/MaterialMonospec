## MODIFIED Requirements

### Requirement: Approval does not modify attachments

The approval workflow SHALL accept optional Lrp image replacement data and an optional Lpr adoption flag. When Lrp replacement data is provided, the system SHALL replace the Lrp attachment as part of the approval transaction. When adoption is requested, the system SHALL copy the existing UrbanPhoto attachment into a new Lrp attachment as part of the approval transaction. The system SHALL NOT replace or delete `AttachType.UrbanPhoto` attachments. When neither replacement nor adoption is provided, existing attachments SHALL remain unchanged. Approval SHALL only accept `PlateNumber`, `TotalWeight`, optional Lrp replacement image changes, and the optional Lpr adoption flag.

#### Scenario: Approve request includes Lrp replacement image

- **WHEN** the administrator submits approval with `LrpReplacementBase64` non-null and non-empty
- **THEN** the API SHALL accept the image payload
- **AND** SHALL replace the corresponding `AttachmentFile` and `UrbanWeighingRecordAttachment` rows for `AttachType.Lrp` as part of the approval transaction
- **AND** old Lrp attachment files on disk SHALL be deleted
- **AND** UrbanPhoto attachments SHALL remain unchanged

#### Scenario: Approve request includes Lpr adoption flag

- **WHEN** the administrator submits approval with `AdoptUrbanPhotoAsLpr == true`
- **AND** the record currently has an `AttachType.UrbanPhoto` attachment and no `AttachType.Lrp` attachment
- **THEN** the API SHALL copy the UrbanPhoto source file to a new `AttachType.Lrp` `AttachmentFile`
- **AND** SHALL create a new `UrbanWeighingRecordAttachment` linking the new Lrp `AttachmentFile` to the record
- **AND** SHALL NOT delete or modify the existing UrbanPhoto `AttachmentFile` or its junction row
- **AND** SHALL record the adoption in edit history via `IsLprAdoptedFromUrbanPhoto = true`

#### Scenario: Approve request excludes replacement and adoption

- **WHEN** the administrator submits approval without `LrpReplacementBase64` and with `AdoptUrbanPhotoAsLpr == false`
- **THEN** existing `UrbanWeighingRecordAttachment` rows SHALL remain unchanged
- **AND** existing `AttachmentFile` records SHALL remain unchanged

#### Scenario: Web approval UI does not provide image replacement or adoption controls

- **WHEN** the administrator uses the Web approval dialog (`WeighingApproval.razor`)
- **THEN** the dialog SHALL NOT provide image file upload controls for Lrp replacement
- **AND** SHALL NOT provide any adoption control
- **AND** replacement and adoption fields SHALL NOT be populated from the Web UI

#### Scenario: UrbanPhoto replacement is not accepted

- **WHEN** the approval request attempts to supply an UrbanPhoto replacement payload
- **THEN** the API SHALL NOT delete or create any `AttachType.UrbanPhoto` attachment
- **AND** the existing UrbanPhoto attachment SHALL remain unchanged
