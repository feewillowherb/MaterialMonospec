## REMOVED Requirements

### Requirement: SettingsDialog window
**Reason**: 由共享 `SettingsWindow` 整窗实现替代；简化对话框无法满足 main 分支功能与 Urban/Main 一致体验。
**Migration**: 消费方改为 `GetRequiredService<SettingsWindow>()` 并 `ShowDialog`；删除对 `SettingsDialog` / `SettingsViewModel` 的引用。

### Requirement: ISettingsSection interface
**Reason**: 分区插件模型随 SettingsDialog 一并弃用。
**Migration**: 删除 `ISettingsSection` 实现类及 `MaterialClientUiModule` 中的 `ISettingsSection` 注册。

### Requirement: SettingsViewModel base class
**Reason**: 由 `SettingsWindowViewModel` 统一管理加载、保存与命令。
**Migration**: 不再注册或解析 `SettingsViewModel`。

### Requirement: Typed setting item controls
**Reason**: 设置项改由 `SettingsWindow` XAML 与 DataGrid 直接绑定，不再使用 `ToggleSettingItem` 等程序化控件。
**Migration**: 删除 `Controls/SettingItems/*`。

### Requirement: Settings section extensibility
**Reason**: 扩展点改为在共享 `SettingsWindow` 内维护完整分区（与 main 一致），不再按程序集注册 Section。
**Migration**: Urban 与 Main 共用同一 7 分区窗口；Urban 特有精简分区需求不再通过 `ISettingsSection` 实现。

## ADDED Requirements

### Requirement: Shared SettingsWindow in MaterialClient.UI
MaterialClient.UI MUST provide a `SettingsWindow` Avalonia `Window` equivalent to MaterialClient `main` branch implementation, including seven settings areas: scale, weighing, camera, license plate recognition, system, sound device, and printer.

#### Scenario: Window layout and navigation
- **WHEN** SettingsWindow is opened
- **THEN** it SHALL display a custom title bar with title "系统设置" and a close control
- **AND** SHALL display a left navigation list with items for all seven settings areas
- **AND** SHALL display a scrollable right content area with section-specific controls bound to `SettingsWindowViewModel`
- **AND** SHALL provide Save and Cancel actions consistent with main branch behavior

#### Scenario: Close without persisting
- **WHEN** user closes the window via cancel or close without completing save
- **THEN** in-memory edits SHALL NOT be written via the save command
- **AND** the window SHALL close via `DetailCloseRequestedMessage` handling where applicable

### Requirement: SettingsWindowViewModel
MaterialClient.UI MUST provide `SettingsWindowViewModel` that loads and saves `SettingsEntity` through `ISettingsService`, and coordinates hardware-related commands using Common-layer services (`ITruckScaleWeightService`, `IHikvisionService`, `ITicketPrintingService`, `ISoundDeviceService`, `ILprDeviceResolver`).

#### Scenario: Load settings on open
- **WHEN** SettingsWindowViewModel is constructed or initialized
- **THEN** it SHALL load current settings from `ISettingsService`
- **AND** SHALL populate all bindable properties for scale, weighing, cameras, LPR devices, system, sound device, and printer sections
- **AND** SHALL refresh available serial ports and printer names where applicable

#### Scenario: Save settings
- **WHEN** user executes the save command
- **THEN** it SHALL persist a complete `SettingsEntity` via `ISettingsService.SaveSettingsAsync`
- **AND** SHALL call `_truckScaleWeightService.RestartAsync()` after successful save
- **AND** SHALL send `DetailCloseRequestedMessage` to close the window
- **AND** SHALL send `SettingsSavedMessage` on the ReactiveUI message bus for consumers that listen

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
