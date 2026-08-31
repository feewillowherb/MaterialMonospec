# Settings UI Specification

## Purpose

定义 MaterialClient.UI 中共享 `SettingsWindow` 设置界面（与 MaterialClient main 分支一致），包括地磅、称重、摄像头、车牌识别、系统、音频、打印机、高拍仪等分区，Urban 宿主另含异常设置与城管配置；ViewModel 持久化与辅助对话框供主应用和 Urban 应用通过 DI 打开。导航模型见 `settings-window-section-navigation`。
## Requirements
### Requirement: Shared SettingsWindow in MaterialClient.UI

MaterialClient.UI MUST provide a `SettingsWindow` Avalonia `Window` equivalent to MaterialClient `main` branch implementation, including settings areas for scale, weighing, camera, license plate recognition, system, sound device, printer, and document camera (高拍仪), and a shared `ProjectInfoWindow` for authorization info display. Urban-only sections (异常设置、城管配置) MAY appear when the host is MaterialClient.Urban.

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

### Requirement: SettingsWindowViewModel

MaterialClient.UI MUST provide `SettingsWindowViewModel` that loads and saves `SettingsEntity` through `ISettingsService`, and coordinates hardware-related commands using Common-layer services (`ITruckScaleWeightService`, `IHikvisionService`, `ITicketPrintingService`, `ISoundDeviceService`, `ILprDeviceResolver`, and document camera / USB camera services).

#### Scenario: Load settings on open

- **WHEN** SettingsWindowViewModel is constructed or initialized
- **THEN** it SHALL load current settings from `ISettingsService`
- **AND** SHALL populate all bindable properties for scale, weighing, cameras, LPR devices, system, sound device, printer, and document camera sections
- **AND** SHALL refresh available serial ports and printer names where applicable

#### Scenario: Save settings

- **WHEN** user executes the save command
- **AND** persistence and post-save steps succeed
- **THEN** it SHALL persist a complete `SettingsEntity` via `ISettingsService.SaveSettingsAsync`
- **AND** on an Urban host SHALL include `UrbanSettingsJson` with 城管配置 core mode fields (see `xiaoshan-upload-config`) without Xiaoshan LocalEvent or config Facade
- **AND** SHALL call `_truckScaleWeightService.RestartAsync()` after successful save
- **AND** SHALL send `DetailCloseRequestedMessage` to close the window
- **AND** SHALL send `SettingsSavedMessage` on the ReactiveUI message bus for consumers that listen
- **AND** persisted flags MUST include `DocumentCameraEnabled`, `IsPrinterEnabled` (or equivalent), and `SoundDeviceEnabled` so device status bar catalog can refresh

#### Scenario: Save failure stays open and informs the user

- **WHEN** user executes the save command
- **AND** persistence or scale restart throws or returns unsuccessful
- **THEN** the ViewModel MUST inform the user of the failure
- **AND** MUST NOT send `DetailCloseRequestedMessage` solely due to that failure
- **AND** MUST NOT swallow the failure in an empty catch with no user-visible outcome

#### Scenario: Camera management commands

- **WHEN** user adds, edits, removes, or tests a camera configuration
- **THEN** the ViewModel SHALL use `AddCameraDialog` and `IHikvisionService` test capture APIs as in main branch
- **AND** SHALL update the in-memory `CameraConfigs` collection bound to the camera DataGrid

#### Scenario: LPR management commands

- **WHEN** user adds, edits, removes, or tests a license plate recognition configuration
- **THEN** the ViewModel SHALL use `AddLprDialog` and `ILprDeviceResolver` as in main branch
- **AND** the LPR DataGrid 操作列 MUST show an enabled 「编辑」 control (not hidden)
- **AND** editing SHALL prefill the dialog from that row (including per-row `DeviceType`) and replace the same collection item on confirm
- **AND** SHALL apply gate IO validation hints after add, edit, or remove

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
- **WHEN** user confirms AddLprDialog with valid input from the add command
- **THEN** it SHALL return a `LicensePlateRecognitionConfigViewModel` added to the parent settings collection
- **AND** SHALL use the dialog’s own `DeviceType` for field visibility defaults

#### Scenario: Edit LPR dialog confirm
- **WHEN** user confirms AddLprDialog opened from the edit command
- **THEN** it SHALL return a `LicensePlateRecognitionConfigViewModel` that replaces the edited row
- **AND** SHALL NOT append a duplicate row

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

### Requirement: Chunked attachment upload toggle in system settings UI

MaterialClient.UI `SettingsWindow` (system settings section) SHALL expose a boolean toggle to enable or disable tus-based chunked attachment upload for Urban attachment sync. The value SHALL bind to `SystemSettings.EnableChunkedAttachmentUpload`, default `false`, and SHALL persist via the existing `ISettingsService` save flow with other system settings.

#### Scenario: Toggle visible in system section

- **WHEN** the operator opens Settings and navigates to the system settings area
- **THEN** the UI SHALL show a control labeled to enable attachment chunked upload (or equivalent Chinese label such as「启用附件分片上传」)
- **AND** the control SHALL reflect the current `EnableChunkedAttachmentUpload` value

#### Scenario: Save persists toggle

- **WHEN** the operator turns the toggle on and saves settings
- **THEN** subsequent loads of settings SHALL show the toggle on
- **AND** Urban attachment sync SHALL treat tus chunked upload as enabled

#### Scenario: Default off for existing installations

- **WHEN** existing settings JSON has no `EnableChunkedAttachmentUpload` property
- **THEN** deserialization SHALL treat the value as `false`
- **AND** attachment sync SHALL continue using multipart upload

### Requirement: Settings page has no global LPR vendor ComboBox

The 车牌识别 settings section MUST NOT present a window-level ComboBox that sets `SystemSettings.LprDeviceType` as the vendor for all LPR rows. Vendor selection SHALL live on `AddLprDialog` (add and edit).

#### Scenario: Operator does not see global vendor combo

- **WHEN** the operator opens 系统设置 and selects the license-plate section
- **THEN** the UI MUST NOT show a single ComboBox that changes vendor type for every existing LPR row

### Requirement: LPR row add and edit share AddLprDialog

车牌识别「增加」与「编辑」MUST 使用同一个 Avalonia 窗口类型 `AddLprDialog` 与同一个 `AddLprDialogViewModel`。系统 MUST NOT 新增仅用于编辑的第二套 LPR 对话框 Window。增加与编辑 MUST 仅在标题/模式与初始值上不同；厂商字段可见性、道闸字段可见性与保存映射 MUST 共用同一套逻辑。

#### Scenario: Edit reuses add dialog type

- **WHEN** 用户在设置页车牌识别表格点击某一行的「编辑」
- **THEN** 系统 MUST 打开 `AddLprDialog`（与「增加」相同的窗口类型）
- **AND** MUST NOT 打开名为 `EditLprDialog` 的独立窗口类型

#### Scenario: Edit titles differ from add

- **WHEN** 对话框以编辑模式打开
- **THEN** 窗口标题 MUST 表明编辑（例如「编辑车牌识别设备」）
- **AND** MUST NOT 仍显示仅适用于增加的标题「添加车牌识别设备」

#### Scenario: Add titles remain add

- **WHEN** 用户点击车牌识别「增加」
- **THEN** 打开的仍为 `AddLprDialog`
- **AND** 窗口标题 MUST 表明添加

### Requirement: Urban host can choose LPR site type; other hosts force scale

On an Urban host, add and edit LPR dialogs MUST let the user select site type among 地磅, 卡口, and 成品, and the settings LPR grid MUST show the selected type. On Standard, SolidWaste, Recycle, and any other non-Urban host, the UI MUST NOT allow changing site type; add and edit MUST result in scale (地磅), and save MUST persist scale for every LPR row in that session.

#### Scenario: Urban add or edit can select checkpoint

- **WHEN** the Urban settings host opens AddLprDialog to add or edit an LPR row
- **THEN** the dialog MUST present the three site types
- **AND** confirming with 卡口 MUST store checkpoint on that row

#### Scenario: Non-Urban add cannot leave scale

- **WHEN** a non-Urban host opens AddLprDialog to add an LPR row
- **THEN** site type MUST be scale
- **AND** the user MUST NOT be able to persist 卡口 or 成品 from that dialog

#### Scenario: Non-Urban save coerces stored rows to scale

- **WHEN** a non-Urban host saves settings that contain LPR rows whose JSON site type is not scale
- **THEN** persisted LPR rows MUST all be scale after that save

