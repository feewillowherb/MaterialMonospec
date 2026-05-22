# Device Status Bar Specification

## Purpose

定义 MaterialClient.UI 中 DeviceStatusBar 共享控件的模板、数据模型和 ViewModel，用于在主应用和 Urban 应用中实时显示设备连接状态。
## Requirements
### Requirement: DeviceStatusBar TemplatedControl
MaterialClient.UI MUST provide a `DeviceStatusBar` TemplatedControl that displays a horizontal list of device status indicators, each showing an icon, label, and online/offline state.

#### Scenario: Control renders device indicators
- **WHEN** DeviceStatusBar is added to a window XAML
- **THEN** it SHALL render a horizontal panel of device status items
- **AND** each item SHALL display a colored circle indicator (green for online, red for offline)
- **AND** each item SHALL display the device name text

#### Scenario: ItemsSource binding
- **WHEN** DeviceStatusBar.ItemsSource is bound to an ObservableCollection of DeviceStatusItem
- **THEN** the control SHALL display one indicator per item
- **AND** SHALL update automatically when items are added or removed

#### Scenario: Online state display
- **WHEN** a DeviceStatusItem has IsOnline = true
- **THEN** the indicator SHALL display a green filled circle
- **AND** the status text SHALL read "在线" (or localized equivalent)

#### Scenario: Offline state display
- **WHEN** a DeviceStatusItem has IsOnline = false
- **THEN** the indicator SHALL display a red filled circle
- **AND** the status text SHALL read "离线" (or localized equivalent)

### Requirement: DeviceStatusItem data model
MaterialClient.UI MUST define a `DeviceStatusItem` record type for representing individual device status entries.

#### Scenario: Record structure
- **WHEN** DeviceStatusItem is instantiated
- **THEN** it SHALL have a `Name` property (string, device display name)
- **AND** SHALL have an `IsOnline` property (bool, device connection state)
- **AND** SHALL be a `record` type (immutable value semantics)

### Requirement: DeviceStatusBarViewModel

MaterialClient.UI MUST provide a `DeviceStatusBarViewModel` that manages the collection of device status items by querying device services and subscribing to status change events. The visible device set MUST be derived from current settings enable flags, not a fixed full hardware list.

#### Scenario: Initial device state loading

- **WHEN** DeviceStatusBarViewModel is constructed
- **THEN** it SHALL build the Devices collection from the dynamic device catalog (see DeviceStatusBar configuration per app)
- **AND** SHALL query each visible device service for its current online/offline state
- **AND** SHALL NOT create DeviceStatusItem entries for disabled optional devices

#### Scenario: Real-time status update

- **WHEN** a device status changes (hardware connects/disconnects)
- **THEN** the corresponding DeviceStatusItem SHALL update within 1 second
- **AND** the UI indicator SHALL change color accordingly
- **AND** updates MUST apply only to devices currently present in the Devices collection

#### Scenario: Event-driven updates via ILocalEventBus

- **WHEN** a device service publishes a status change event
- **THEN** DeviceStatusBarViewModel SHALL handle the event via ILocalEventHandler
- **AND** SHALL update only the affected device's status if that device is currently visible
- **AND** SHALL NOT re-query all devices on a single device change

#### Scenario: Per-window instantiation

- **WHEN** DeviceStatusBarViewModel is resolved from the DI container
- **THEN** it SHALL be registered as ITransientDependency (per-window scope)
- **AND** each window instance SHALL have its own DeviceStatusBarViewModel

#### Scenario: Catalog refresh after settings change

- **WHEN** settings are saved and optional device enable flags change
- **THEN** DeviceStatusBarViewModel MUST rebuild the Devices collection to add or remove optional indicators
- **AND** MUST subscribe or unsubscribe status events accordingly

### Requirement: DeviceStatusBar configuration per app

Each consuming app MUST use the shared dynamic device catalog. The status bar MUST default to core weighing devices only; optional peripherals MUST appear only when enabled in settings.

#### Scenario: Default visible device set

- **WHEN** MaterialClient main app or MaterialClient.Urban initializes DeviceStatusBarViewModel
- **AND** document camera, printer, and sound device are all disabled in settings
- **THEN** the status bar SHALL show indicators only for: truck scale (地磅), Hikvision weighing camera(s) (摄像头), and license plate recognition (车牌识别)
- **AND** SHALL NOT show document camera, printer, or sound device indicators

#### Scenario: Document camera visible when enabled

- **WHEN** `DocumentCameraEnabled` is true
- **THEN** the status bar SHALL include a document camera (高拍仪 / USB camera) indicator
- **AND** SHALL reflect its online/offline state

#### Scenario: Document camera hidden when disabled

- **WHEN** `DocumentCameraEnabled` is false
- **THEN** the status bar MUST NOT display a document camera indicator
- **AND** MUST NOT reserve layout space for it

#### Scenario: Printer visible when enabled

- **WHEN** printer is enabled in settings (`IsPrinterEnabled` or equivalent is true)
- **THEN** the status bar SHALL include a printer indicator

#### Scenario: Printer hidden when disabled

- **WHEN** printer is not enabled in settings
- **THEN** the status bar MUST NOT display a printer indicator

#### Scenario: Sound device visible when enabled

- **WHEN** `SoundDeviceEnabled` is true
- **THEN** the status bar SHALL include a sound device indicator

#### Scenario: Sound device hidden when disabled

- **WHEN** `SoundDeviceEnabled` is false
- **THEN** the status bar MUST NOT display a sound device indicator

#### Scenario: Urban uses same catalog rules

- **WHEN** MaterialClient.Urban initializes DeviceStatusBarViewModel
- **THEN** it SHALL use the same dynamic catalog rules as the main app
- **AND** with default urban settings (optional devices off) SHALL match the three-device default set

### Requirement: Centralized device status catalog
MaterialClient.UI MUST provide a single implementation that builds and updates the DeviceStatusBar item collection for all consuming apps.

#### Scenario: Shared catalog between apps
- **WHEN** DeviceStatusBarViewModel is constructed in either MaterialClient or MaterialClient.Urban
- **THEN** it SHALL use the same catalog logic to populate Devices
- **AND** SHALL subscribe to the same ILocalEventBus device status events

#### Scenario: Urban status bar parity
- **WHEN** a device connects or disconnects on an Urban deployment with full peripherals
- **THEN** the corresponding indicator SHALL update within 1 second
- **AND** online/offline colors SHALL match the main app (green online, red offline)

