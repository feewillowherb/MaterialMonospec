## MODIFIED Requirements

### Requirement: Shared SettingsWindow in MaterialClient.UI

MaterialClient.UI MUST provide a `SettingsWindow` Avalonia `Window` equivalent to MaterialClient `main` branch implementation, including settings areas for scale, weighing, camera, license plate recognition, system, sound device, printer, and document camera (高拍仪), and a shared `ProjectInfoWindow` for authorization info display.

#### Scenario: Window layout and navigation

- **WHEN** SettingsWindow is opened
- **THEN** it SHALL display a custom title bar with title "系统设置" and a close control
- **AND** SHALL display a left navigation list with items for all settings areas including document camera (高拍仪)
- **AND** SHALL display a scrollable right content area with section-specific controls bound to `SettingsWindowViewModel`
- **AND** SHALL provide Save and Cancel actions consistent with main branch behavior

#### Scenario: Close without persisting

- **WHEN** user closes the window via cancel or close without completing save
- **THEN** in-memory edits SHALL NOT be written via the save command
- **AND** the window SHALL close via `DetailCloseRequestedMessage` handling where applicable

## ADDED Requirements

### Requirement: Shared ProjectInfoWindow in MaterialClient.UI

MaterialClient.UI MUST provide a `ProjectInfoWindow` Avalonia `Window` with `ProjectInfoWindowViewModel`, implementing `ITransientDependency` for DI resolution. The window SHALL display authorization info fields: project name, product name, expiration date (red), machine code (masked), and auth code (masked).

#### Scenario: Window resolved from DI

- **WHEN** a consuming application calls `_serviceProvider.GetRequiredService<ProjectInfoWindow>()`
- **THEN** the DI container SHALL return a `MaterialClient.UI.Views.ProjectInfoWindow` instance
- **AND** the instance SHALL have `ProjectInfoWindowViewModel` as its `DataContext`

#### Scenario: Window style and layout

- **WHEN** ProjectInfoWindow is displayed
- **THEN** it SHALL have fixed size 500×300, `CanResize=False`, `SystemDecorations="None"`
- **AND** SHALL display a blue title bar (`#6498FE`) with title "项目信息" and a close button (✕)
- **AND** SHALL display 5 info rows: 项目信息、产品名称、到期时间（红色 `#DC3545`）、机器码、授权码

#### Scenario: Consuming application opens ProjectInfoWindow

- **WHEN** a consuming application (MaterialClient or MaterialClient.Urban) opens the project info window
- **THEN** it SHALL resolve `ProjectInfoWindow` from DI
- **AND** SHALL call `ProjectInfoWindowViewModel.InitializeAsync()` before showing
- **AND** SHALL display via `ShowDialog(parentWindow)` if a parent window is available
