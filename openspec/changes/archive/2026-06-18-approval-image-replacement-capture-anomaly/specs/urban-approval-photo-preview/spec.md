## ADDED Requirements

### Requirement: Approval dialog photo replace button overlay

The `WeighingRecordEditDialog` SHALL provide a replace button on each photo preview section (Lrp and UrbanPhoto), allowing the operator to initiate image replacement.

#### Scenario: Lrp section shows replace button

- **WHEN** the approval edit dialog renders the Lrp photo preview section
- **THEN** a "替换" button SHALL be visible below or overlaid on the Lrp preview area

#### Scenario: UrbanPhoto section shows replace button

- **WHEN** the approval edit dialog renders the UrbanPhoto photo preview section
- **THEN** a "替换" button SHALL be visible below or overlaid on the UrbanPhoto preview area

#### Scenario: Replace button triggers file picker

- **WHEN** the operator clicks the "替换" button on either photo section
- **THEN** the system SHALL trigger the corresponding replace command (`ReplaceLrpCommand` or `ReplaceUrbanPhotoCommand`)
- **AND** a native file picker SHALL open

### Requirement: Lrp empty shows capture anomaly warning in client approval dialog

The `WeighingRecordEditDialog` SHALL display a "抓拍异常" warning indicator when the Lrp photo attachment is absent.

#### Scenario: Lrp empty with anomaly warning

- **WHEN** the approval dialog loads photos and `LprPhotoPath` is null or empty
- **THEN** the Lrp preview area SHALL display the default placeholder image
- **AND** SHALL display "抓拍异常" warning text in a distinct style (e.g. yellow/orange foreground)

#### Scenario: Lrp present without anomaly warning

- **WHEN** the approval dialog loads photos and `LprPhotoPath` is not null or empty
- **THEN** the "抓拍异常" warning text SHALL NOT be displayed
