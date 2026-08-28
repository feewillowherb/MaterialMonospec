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
- **THEN** the ViewModel SHALL use `AddLprDialog` and `ILprDeviceResolver`
- **AND** SHALL pass or bind that row’s `DeviceType` into the dialog (not a settings-wide vendor ComboBox)
- **AND** SHALL resolve test capture with `ILprDeviceResolver.GetDevice` using that row’s `DeviceType`
- **AND** SHALL apply gate IO validation hints using each row’s `DeviceType`
- **AND** MUST NOT hide entire LPR DataGrid columns from a global `SystemSettings.LprDeviceType`

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
- **THEN** it SHALL return a `LicensePlateRecognitionConfigViewModel` including `DeviceType` selected in the dialog
- **AND** SHALL use that selected `DeviceType` for field visibility and vendor defaults
- **AND** MUST NOT take vendor type only from a settings-page global ComboBox

## ADDED Requirements

### Requirement: Settings page has no global LPR vendor ComboBox

The 车牌识别 settings section MUST NOT present a window-level ComboBox that sets `SystemSettings.LprDeviceType` as the vendor for all LPR rows. Vendor selection SHALL live on `AddLprDialog` (add and edit).

#### Scenario: Operator does not see global vendor combo

- **WHEN** the operator opens 系统设置 and selects the license-plate section
- **THEN** the UI MUST NOT show a single ComboBox that changes vendor type for every existing LPR row
