## MODIFIED Requirements

### Requirement: Approval does not modify attachments

The approval workflow SHALL accept optional Lrp image replacement data via `LrpReplacementBase64`. When provided, the system SHALL create or replace the Lrp attachment as part of the approval transaction. UrbanPhoto attachments SHALL NOT be modified during approval. When no Lrp replacement data is provided, existing attachments SHALL remain unchanged. Approval SHALL only accept `PlateNumber`, `TotalWeight`, and optional Lrp replacement image changes.

#### Scenario: Approve request includes Lrp replacement image

- **WHEN** the administrator submits approval with `LrpReplacementBase64` non-null and non-empty
- **THEN** the API SHALL accept the image payload
- **AND** SHALL create or replace the Lrp `AttachmentFile` and `UrbanWeighingRecordAttachment` rows as part of the approval transaction
- **AND** old Lrp attachment files on disk SHALL be deleted when replacing an existing Lrp attachment

#### Scenario: Approve request with adopted UrbanPhoto as Lrp

- **WHEN** the administrator submits approval with `LrpReplacementBase64` containing the UrbanPhoto image (via adopt control in the Web or client UI)
- **THEN** the API SHALL create a new Lrp attachment from the payload
- **AND** the UrbanPhoto attachment SHALL remain unchanged

#### Scenario: Approve request excludes Lrp replacement image

- **WHEN** the administrator submits approval without `LrpReplacementBase64`
- **THEN** existing `UrbanWeighingRecordAttachment` rows SHALL remain unchanged
- **AND** existing `AttachmentFile` records SHALL remain unchanged

#### Scenario: Web approval UI provides Lrp modification controls only

- **WHEN** the administrator uses the Web approval dialog (`WeighingApproval.razor`)
- **THEN** the dialog SHALL provide Lrp image modification controls (replace via file picker and adopt when Lrp empty and UrbanPhoto present)
- **AND** SHALL NOT provide UrbanPhoto image replacement controls
- **AND** `UrbanPhotoReplacementBase64` SHALL NOT be populated from the Web UI

#### Scenario: Legacy UrbanPhoto replacement payload ignored

- **WHEN** the administrator or an old client submits approval with non-empty legacy `UrbanPhotoReplacementBase64`
- **THEN** the API SHALL ignore the UrbanPhoto replacement payload
- **AND** SHALL NOT modify UrbanPhoto attachments
