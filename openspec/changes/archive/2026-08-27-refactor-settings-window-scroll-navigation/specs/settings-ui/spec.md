## MODIFIED Requirements

### Requirement: Shared SettingsWindow in MaterialClient.UI

MaterialClient.UI MUST provide a `SettingsWindow` Avalonia `Window` equivalent to MaterialClient `main` branch implementation, including settings areas for scale, weighing, camera, license plate recognition, system, sound device, printer, and document camera (高拍仪), and a shared `ProjectInfoWindow` for authorization info display.

#### Scenario: Window layout and navigation

- **WHEN** SettingsWindow is opened
- **THEN** it SHALL display a custom title bar with title "系统设置" and a close control
- **AND** SHALL display a left navigation list with items for all settings areas including document camera (高拍仪)
- **AND** SHALL display a right content area that shows **only the selected section’s** controls bound to `SettingsWindowViewModel`, with scrolling confined to that section when content overflows
- **AND** SHALL provide Save and Cancel actions consistent with main branch behavior

#### Scenario: Close without persisting

- **WHEN** user closes the window via cancel or close without completing save
- **THEN** in-memory edits SHALL NOT be written via the save command
- **AND** the window SHALL close via `DetailCloseRequestedMessage` handling where applicable
