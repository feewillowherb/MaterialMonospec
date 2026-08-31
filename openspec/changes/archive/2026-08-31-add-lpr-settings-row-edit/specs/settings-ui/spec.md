## ADDED Requirements

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

## MODIFIED Requirements

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
