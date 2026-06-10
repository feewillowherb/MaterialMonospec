# Settings UI Specification

## Purpose

定义 MaterialClient.UI 中共享 `SettingsWindow` 设置界面（与 MaterialClient main 分支一致），包括八个设置分区（含高拍仪）、ViewModel 持久化与辅助对话框，供主应用和 Urban 应用通过 DI 打开。
## Requirements
### Requirement: Shared SettingsWindow in MaterialClient.UI

MaterialClient.UI MUST provide a `SettingsWindow` Avalonia `Window` equivalent to MaterialClient `main` branch implementation, including settings areas for scale, weighing, camera, license plate recognition, system, sound device, printer, and document camera (高拍仪).

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

### Requirement: SettingsWindowViewModel

MaterialClient.UI MUST provide `SettingsWindowViewModel` that loads and saves `SettingsEntity` through `ISettingsService`, and coordinates hardware-related commands using Common-layer services (`ITruckScaleWeightService`, `IHikvisionService`, `ITicketPrintingService`, `ISoundDeviceService`, `ILprDeviceResolver`, and document camera / USB camera services).

#### Scenario: Load settings on open

- **WHEN** SettingsWindowViewModel is constructed or initialized
- **THEN** it SHALL load current settings from `ISettingsService`
- **AND** SHALL populate all bindable properties for scale, weighing, cameras, LPR devices, system, sound device, printer, and document camera sections
- **AND** SHALL refresh available serial ports and printer names where applicable

#### Scenario: Save settings

- **WHEN** user executes the save command
- **THEN** it SHALL persist a complete `SettingsEntity` via `ISettingsService.SaveSettingsAsync`
- **AND** SHALL call `_truckScaleWeightService.RestartAsync()` after successful save
- **AND** SHALL send `DetailCloseRequestedMessage` to close the window
- **AND** SHALL send `SettingsSavedMessage` on the ReactiveUI message bus for consumers that listen
- **AND** persisted flags MUST include `DocumentCameraEnabled`, `IsPrinterEnabled` (or equivalent), and `SoundDeviceEnabled` so device status bar catalog can refresh

#### Scenario: Camera management commands

- **WHEN** user adds, edits, removes, or tests a camera configuration
- **THEN** the ViewModel SHALL use `AddCameraDialog` and `IHikvisionService` test capture APIs as in main branch
- **AND** SHALL update the in-memory `CameraConfigs` collection bound to the camera DataGrid

#### Scenario: LPR management commands

- **WHEN** user adds, edits, removes, or tests a license plate recognition configuration
- **THEN** the ViewModel SHALL use `AddLprDialog` and `ILprDeviceResolver` as in main branch
- **AND** SHALL apply gate IO validation hints and column visibility based on `LprDeviceType`

#### Scenario: Sound device test

- **WHEN** user runs sound device test with sound device enabled
- **THEN** the ViewModel SHALL invoke `ISoundDeviceService.PlayTextV2TestAsync` and display test result text

#### Scenario: Document camera section binding

- **WHEN** user toggles document camera enable in settings
- **THEN** `DocumentCameraEnabled` on the ViewModel MUST update immediately for UI state
- **AND** dependent controls in the document camera section MUST enable or disable consistent with the toggle

### Requirement: Settings helper dialogs and converters
MaterialClient.UI MUST include `AddCameraDialog`, `AddLprDialog`, and their ViewModels, plus enum display converters (`ScaleUnitConverter`, `LprDeviceTypeConverter`, `StreamTypeConverter`) required by SettingsWindow XAML bindings.

#### Scenario: Add camera dialog
- **WHEN** user confirms AddCameraDialog with valid input
- **THEN** it SHALL return a `CameraConfigViewModel` added to the parent settings collection

#### Scenario: Add LPR dialog
- **WHEN** user confirms AddLprDialog with valid input
- **THEN** it SHALL return a `LicensePlateRecognitionConfigViewModel` added to the parent settings collection
- **AND** SHALL respect the current `LprDeviceType` for field visibility defaults

### Requirement: Consuming application entry points
MaterialClient and MaterialClient.Urban MUST open settings exclusively through the shared `SettingsWindow` from MaterialClient.UI.

#### Scenario: Main application opens settings
- **WHEN** user triggers system settings from the attended weighing UI
- **THEN** the application SHALL resolve `SettingsWindow` from DI and show it as a dialog over the parent window
- **AND** MUST NOT open `SettingsDialog` or resolve `SettingsViewModel`

#### Scenario: Urban application opens settings
- **WHEN** user clicks the top-bar "系统设置" button
- **THEN** Urban SHALL resolve `SettingsWindow` from DI and show it as a dialog
- **AND** MUST NOT open `SettingsDialog` or resolve `SettingsViewModel`

### Requirement: MaterialClient.UI project dependencies for settings
MaterialClient.UI MUST reference `Avalonia.Controls.DataGrid` and compile all Settings XAML under the UI assembly.

#### Scenario: Build UI library
- **WHEN** the solution builds MaterialClient.UI
- **THEN** SettingsWindow and related dialogs SHALL compile without referencing the MaterialClient executable project
- **AND** SHALL only depend on MaterialClient.Common for services and entities

