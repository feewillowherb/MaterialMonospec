## MODIFIED Requirements

### Requirement: Approval dialog photo replace button overlay

The `WeighingRecordEditDialog` SHALL provide a replace button on the Lrp photo preview section only, allowing the operator to initiate Lrp image modification via file picker or adopt (see `approval-image-replacement`). The UrbanPhoto section SHALL NOT provide a replace button.

#### Scenario: Lrp section shows replace button

- **WHEN** the approval edit dialog renders the Lrp photo preview section
- **THEN** a「替换」button SHALL be visible below or overlaid on the Lrp preview area

#### Scenario: Lrp section shows adopt button when Lrp empty and UrbanPhoto present

- **WHEN** the approval edit dialog renders with `LprPhotoPath` null or empty and `CameraPhotoPath` not null or empty
- **THEN** an「采纳」button SHALL be visible on the Lrp preview area alongside「替换」
- **WHEN** the operator clicks「采纳」
- **THEN** the system SHALL invoke the adopt command to create a local Lrp attachment from UrbanPhoto via the Service layer
- **AND** SHALL update `LprPhotoPath` to the new local Lrp path for preview

#### Scenario: UrbanPhoto section has no replace button

- **WHEN** the approval edit dialog renders the UrbanPhoto photo preview section
- **THEN** a「替换」button SHALL NOT be visible
- **AND** the UrbanPhoto preview SHALL be read-only (click-to-view only per existing preview requirement)

#### Scenario: Replace button triggers Lrp file picker only

- **WHEN** the operator clicks the「替换」button on the Lrp photo section
- **THEN** the system SHALL trigger `ReplaceLrpCommand` (or equivalent)
- **AND** a native file picker SHALL open for Lrp modification only

---

## ADDED Requirements

### Requirement: Web approval photo preview Lrp adopt control

The UrbanManagement `WeighingPhotoPreview` component used in the approval modal SHALL provide adopt behavior when Lrp is empty and UrbanPhoto is present. Web adopt SHALL stage `LrpReplacementBase64` for `ApproveAsync` (not local attachment creation).

#### Scenario: Web Lrp adopt button visible

- **WHEN** `WeighingPhotoPreview` renders with `LprImageBase64` null or empty, `UrbanPhotoImageBase64` not null or empty, and `EnableReplacement` is true
- **THEN** an「采纳」button SHALL be displayed on the Lrp section
- **WHEN** the operator clicks「采纳」
- **THEN** the component SHALL set pending Lrp replacement Base64 from `UrbanPhotoImageBase64`
- **AND** SHALL invoke `LprReplacementChanged` with that Base64
- **AND** the Lrp preview SHALL show the UrbanPhoto image
- **AND** the UrbanPhoto section SHALL remain unchanged

#### Scenario: Web UrbanPhoto section read-only during approval

- **WHEN** `WeighingPhotoPreview` renders with `EnableReplacement` true
- **THEN** the UrbanPhoto section SHALL NOT display a replace button or file input
- **AND** SHALL NOT invoke `UrbanPhotoReplacementChanged`

#### Scenario: Web adopt button hidden when Lrp exists

- **WHEN** `LprImageBase64` is not null or empty
- **THEN** the「采纳」button SHALL NOT be displayed on the Lrp section
