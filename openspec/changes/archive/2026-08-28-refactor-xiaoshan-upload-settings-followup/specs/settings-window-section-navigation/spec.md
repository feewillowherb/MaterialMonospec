## ADDED Requirements

### Requirement: Section visibility is driven by SelectedSettingsSection

MaterialClient.UI `SettingsWindow` SHALL bind each settings section’s visibility to `SettingsWindowViewModel.SelectedSettingsSection` (or equivalent computed flags). Selecting a left navigation item SHALL update that property. The primary path MUST NOT register navigation controls in a `FindControl` dictionary or iterate the section host’s children in code-behind to set `IsVisible`.

#### Scenario: Navigation updates selected section property

- **WHEN** the operator selects a visible navigation item whose tag is `WeighingSettings`
- **THEN** `SelectedSettingsSection` SHALL equal `WeighingSettings`
- **AND** only the weighing section SHALL be visible

#### Scenario: No nav registry for section switching

- **WHEN** a maintainer adds a new settings section following the supported pattern
- **THEN** they SHALL add a navigation item and a section whose visibility binds to the selected section key
- **AND** they MUST NOT be required to register the item in a code-behind name dictionary for switching
