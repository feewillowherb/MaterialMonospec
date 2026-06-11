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

### Requirement: Urban 异常阈值设置区块

设置窗口 SHALL 提供 `UrbanAnomalyDetection` 配置编辑区块，包含 `UpperLimit`、`LowerLimit`、`DeviationPercentage` 三个字段。

#### Scenario: Urban 模式显示设置区块
- **WHEN** 当前产品模式为 `UrbanMode`
- **THEN** 设置窗口 MUST 显示 Urban 异常阈值设置区块
- **AND** 区块内 MUST 提供上限、下限、偏差百分比可编辑控件

#### Scenario: 非 Urban 模式隐藏设置区块
- **WHEN** 当前产品模式不是 `UrbanMode`
- **THEN** 设置窗口 MUST NOT 显示 Urban 异常阈值设置区块

### Requirement: Urban 异常阈值区块位置

Urban 异常阈值设置区块 SHALL 固定显示在系统设置页面内容的最下方。

#### Scenario: 区块顺序
- **WHEN** 设置窗口渲染系统设置区域
- **THEN** Urban 异常阈值设置区块 MUST 位于已有系统设置项之后
- **AND** MUST 作为系统设置区域最后一个配置分组

### Requirement: Urban 异常阈值持久化

用户在设置窗口修改 Urban 异常阈值后，系统 SHALL 通过现有设置保存流程持久化并在下次加载时恢复。

#### Scenario: 保存阈值
- **WHEN** 用户修改 `UpperLimit`、`LowerLimit`、`DeviationPercentage` 并点击保存
- **THEN** 系统 MUST 通过 `ISettingsService.SaveSettingsAsync` 持久化三个值

#### Scenario: 重新打开设置窗口
- **WHEN** 设置窗口重新打开并加载设置
- **THEN** 系统 MUST 显示上次已保存的 Urban 异常阈值

