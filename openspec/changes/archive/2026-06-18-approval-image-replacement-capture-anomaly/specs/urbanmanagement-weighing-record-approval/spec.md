## MODIFIED Requirements

### Requirement: Approval does not modify attachments

The approval workflow SHALL accept optional image replacement data for Lrp and UrbanPhoto attachments. When replacement data is provided, the system SHALL replace the corresponding attachments as part of the approval transaction. When no replacement data is provided, existing attachments SHALL remain unchanged. Approval SHALL only accept `PlateNumber`, `TotalWeight`, and optional replacement image changes.

#### Scenario: Approve request includes replacement image

- **WHEN** the administrator submits approval with `LrpReplacementBase64` or `UrbanPhotoReplacementBase64` non-null and non-empty
- **THEN** the API SHALL accept the image payload
- **AND** SHALL replace the corresponding `AttachmentFile` and `UrbanWeighingRecordAttachment` rows as part of the approval transaction
- **AND** old attachment files on disk SHALL be deleted

#### Scenario: Approve request excludes replacement image

- **WHEN** the administrator submits approval without any replacement image data
- **THEN** existing `UrbanWeighingRecordAttachment` rows SHALL remain unchanged
- **AND** existing `AttachmentFile` records SHALL remain unchanged

#### Scenario: Web approval UI does not provide image replacement controls

- **WHEN** the administrator uses the Web approval dialog (`WeighingApproval.razor`)
- **THEN** the dialog SHALL NOT provide image file upload controls for replacement
- **AND** replacement image fields SHALL NOT be populated from the Web UI
