## ADDED Requirements

### Requirement: Standard mode material grid single-click material selection
`StandardModeFormView` SHALL open the material selection Popup with a single click on the material name cell, without requiring a prior row-selection click.

#### Scenario: Single click opens material popup
- **WHEN** user clicks the material name cell in the Standard mode DataGrid
- **THEN** the material selection Popup SHALL open immediately
- **AND** `StandardWeighingDetailViewModel.IsMaterialPopupOpen` SHALL be `true`

#### Scenario: Popup reopens after light dismiss
- **WHEN** user opens the material selection Popup
- **AND** user dismisses the Popup by clicking outside (light dismiss)
- **AND** user clicks the material name cell again
- **THEN** the Popup SHALL open again on the first click

### Requirement: Standard mode material popup close state synchronization
When the material selection Popup closes for any reason without confirming a material, the system SHALL reset popup-related ViewModel state so subsequent opens work correctly.

#### Scenario: Light dismiss resets popup state
- **WHEN** user dismisses the material selection Popup via light dismiss
- **THEN** `IsMaterialPopupOpen` SHALL become `false`
- **AND** `CurrentMaterialRow` SHALL be cleared

#### Scenario: Confirmed selection closes popup
- **WHEN** user selects a material from the Popup
- **THEN** `IsMaterialPopupOpen` SHALL become `false`
- **AND** the target `MaterialItemRow.SelectedMaterial` SHALL be updated

### Requirement: Standard mode unit column inline editing with material prerequisite
The unit column in `StandardModeFormView` SHALL use inline editing (editor in `CellTemplate`, column marked read-only to DataGrid) and SHALL NOT enter DataGrid cell edit mode. The unit selector SHALL be disabled until a material is selected.

#### Scenario: Unit selector disabled without material
- **WHEN** a DataGrid row has no `SelectedMaterial`
- **THEN** the unit ComboBox in that row SHALL be disabled
- **AND** clicking the unit cell SHALL NOT block interaction with other DataGrid cells

#### Scenario: Unit selector enabled after material selected
- **WHEN** a DataGrid row has a `SelectedMaterial` and loaded `MaterialUnits`
- **THEN** the unit ComboBox SHALL be enabled
- **AND** user SHALL be able to change `SelectedMaterialUnit` via the inline ComboBox

#### Scenario: Other columns remain clickable after unit cell interaction
- **WHEN** user clicks the unit cell on a row without a selected material
- **THEN** user SHALL still be able to click material name, waybill quantity, or other rows without extra dismiss steps
