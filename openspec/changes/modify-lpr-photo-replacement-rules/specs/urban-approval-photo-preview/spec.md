## MODIFIED Requirements

### Requirement: Approval dialog photo replace button overlay

The `WeighingRecordEditDialog` SHALL provide a 替换 button only on the Lrp photo preview section. The UrbanPhoto preview section SHALL NOT display a 替换 button or any image-replacement control. The Lrp preview section SHALL additionally expose an「采纳为车牌照」(adopt-as-Lpr) button that is visible only when `LprPhotoPath` is null or empty AND `CameraPhotoPath` is non-empty.

#### Scenario: Lrp section shows replace button

- **WHEN** the approval edit dialog renders the Lrp photo preview section
- **THEN** a "替换" button SHALL be visible below or overlaid on the Lrp preview area
- **AND** activating it SHALL trigger `ReplaceLrpCommand`

#### Scenario: UrbanPhoto section has no replace button

- **WHEN** the approval edit dialog renders the UrbanPhoto preview section
- **THEN** no "替换" button SHALL be rendered
- **AND** no `ReplaceUrbanPhotoCommand` SHALL be exposed by the dialog ViewModel

#### Scenario: Adopt-as-Lpr button visible when Lpr empty and UrbanPhoto present

- **WHEN** the approval edit dialog renders AND `LprPhotoPath` is null or empty AND `CameraPhotoPath` is non-empty
- **THEN** an「采纳为车牌照」button SHALL be visible on or below the Lrp preview area
- **AND** activating it SHALL trigger `AdoptUrbanPhotoAsLprCommand`

#### Scenario: Adopt-as-Lpr button hidden when Lpr present

- **WHEN** the approval edit dialog renders AND `LprPhotoPath` is non-empty
- **THEN** the「采纳为车牌照」button SHALL NOT be visible
- **AND** only the "替换" button SHALL remain on the Lrp section

#### Scenario: Adopt-as-Lpr button hidden when UrbanPhoto absent

- **WHEN** the approval edit dialog renders AND `CameraPhotoPath` is null or empty
- **THEN** the「采纳为车牌照」button SHALL NOT be visible
- **AND** the Lrp preview area SHALL display the placeholder plus the 抓拍异常 warning only

#### Scenario: Replace button triggers file picker

- **WHEN** the operator clicks the "替换" button on the Lrp section
- **THEN** the system SHALL trigger `ReplaceLrpCommand`
- **AND** a native file picker SHALL open
