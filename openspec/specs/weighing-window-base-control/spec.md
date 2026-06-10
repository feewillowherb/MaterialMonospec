# Weighing Window Base Control Specification

## Purpose

定义 MaterialClient.UI 中 WeighingWindowBase 共享 UserControl 的布局结构、依赖属性和交互行为，为 AttendedWeighingWindow 和 UrbanAttendedWeighingWindow 提供统一的窗口基础控件。

## Requirements
### Requirement: WeighingWindowBase UserControl layout structure
MaterialClient.UI SHALL provide a `WeighingWindowBase` UserControl with a 4-row Grid layout: header bar (Row 0), weight area content slot (Row 1), main content slot (Row 2), and device status bar (Row 3).

#### Scenario: Four-row Grid structure
- **WHEN** WeighingWindowBase is rendered
- **THEN** Row 0 SHALL be a header bar with `Background="{DynamicResource PrimaryBlue}"`
- **AND** Row 1 SHALL contain a ContentPresenter bound to the `WeightAreaContent` dependency property
- **AND** Row 2 SHALL contain a ContentPresenter bound to the `MainContent` dependency property
- **AND** Row 3 SHALL contain a `DeviceStatusBar` bound to the `DeviceStatuses` and `CameraStatusDetails` dependency properties

#### Scenario: Header bar three-column layout
- **WHEN** the header bar (Row 0) is rendered
- **THEN** it SHALL use a 3-column Grid (Auto, *, Auto)
- **AND** Column 0 SHALL contain a ContentPresenter bound to `HeaderLeftContent` DP (logo/title area)
- **AND** Column 1 SHALL contain a ContentPresenter bound to `MenuItems` DP (center menu area)
- **AND** Column 2 SHALL contain minimize and close buttons using `titlebar-minimize-button` and `titlebar-close-button` style classes

### Requirement: WeighingWindowBase dependency properties
WeighingWindowBase SHALL expose dependency properties for content injection: `HeaderLeftContent`, `MenuItems`, `WeightAreaContent`, `MainContent`, `DeviceStatuses`, and `CameraStatusDetails`.

#### Scenario: Content injection via dependency properties
- **WHEN** a consuming Window sets `WeightAreaContent` on a WeighingWindowBase instance
- **THEN** the content SHALL appear in Row 1 of the layout
- **AND** SHALL fill the available width

#### Scenario: DeviceStatusBar data binding
- **WHEN** `DeviceStatuses` DP is bound to a collection on the host Window's DataContext
- **THEN** the embedded DeviceStatusBar SHALL display the device status indicators
- **AND** the same SHALL apply for `CameraStatusDetails` DP

### Requirement: Window control buttons in base control
WeighingWindowBase SHALL include minimize (─) and close (✕) buttons in the header bar that communicate with the host Window via routed events.

#### Scenario: Minimize button interaction
- **WHEN** the minimize button is clicked
- **THEN** a routed event SHALL be raised that the host Window handles to set `WindowState.Minimized`

#### Scenario: Close button interaction
- **WHEN** the close button is clicked
- **THEN** a routed event SHALL be raised that the host Window handles to call `Close()`

### Requirement: Title bar drag support
WeighingWindowBase header bar (Row 0) SHALL support pointer-pressed events for window dragging.

#### Scenario: Title bar drag
- **WHEN** the user presses and drags on the header bar area
- **THEN** a routed event SHALL be raised that the host Window handles to call `BeginMoveDrag`

### Requirement: AttendedWeighingWindow uses WeighingWindowBase
AttendedWeighingWindow SHALL use WeighingWindowBase as its Content, injecting its specific menu items (数据管理, 系统设置, 项目信息, 数据同步, 退出登录), delivery-type weight area, and 3-column main grid via the DP slots.

#### Scenario: AttendedWeighingWindow composition
- **WHEN** AttendedWeighingWindow is initialized
- **THEN** its Content SHALL be a Panel containing WeighingWindowBase and OverlayDialogHost
- **AND** WeighingWindowBase.HeaderLeftContent SHALL contain the logo Image
- **AND** WeighingWindowBase.MenuItems SHALL contain the 5 menu buttons + data management Popup
- **AND** WeighingWindowBase.WeightAreaContent SHALL contain the delivery-type selector, weight display, and plate number
- **AND** WeighingWindowBase.MainContent SHALL contain the 3-column Grid (records, detail, camera+bill)
- **AND** the Popup for 数据管理 SHALL remain functional with PlacementTarget on the data management button

#### Scenario: AttendedWeighingWindow visual parity
- **WHEN** the refactored AttendedWeighingWindow is rendered
- **THEN** it SHALL be visually identical to the pre-refactor version
- **AND** all existing interactions (menu clicks, popup, dialogs) SHALL work unchanged

### Requirement: UrbanAttendedWeighingWindow uses WeighingWindowBase
UrbanAttendedWeighingWindow SHALL use WeighingWindowBase as its Content, injecting its specific "凡" logo, single 系统设置 menu item, simplified weight display, and 2-column main grid via the DP slots.

#### Scenario: UrbanAttendedWeighingWindow composition
- **WHEN** UrbanAttendedWeighingWindow is initialized
- **THEN** its Content SHALL be a Grid containing WeighingWindowBase and resize grip Borders
- **AND** WeighingWindowBase.HeaderLeftContent SHALL contain the "凡" logo Border and title TextBlocks
- **AND** WeighingWindowBase.MenuItems SHALL contain the single 系统设置 button
- **AND** WeighingWindowBase.WeightAreaContent SHALL contain the weight text and status TextBlocks
- **AND** WeighingWindowBase.MainContent SHALL contain the 2-column Grid (vehicle records, photo sidebar)

#### Scenario: Urban header style normalization
- **WHEN** the Urban header bar is rendered via WeighingWindowBase
- **THEN** it SHALL use `{DynamicResource PrimaryBlue}` background (same as MaterialClient)
- **AND** menu buttons SHALL use `popup-menu-item-button` style class
- **AND** window control buttons SHALL use `titlebar-minimize-button` and `titlebar-close-button` style classes

#### Scenario: Urban resize grips preserved
- **WHEN** the refactored UrbanAttendedWeighingWindow is rendered
- **THEN** the resize grip Borders SHALL remain outside WeighingWindowBase (siblings in the Window's root Grid)
- **AND** resize functionality SHALL work unchanged

#### Scenario: UrbanAttendedWeighingWindow visual parity
- **WHEN** the refactored UrbanAttendedWeighingWindow is rendered
- **THEN** it SHALL be visually identical to the pre-refactor version (except for header color normalization to PrimaryBlue)
- **AND** all existing interactions (tab clicks, record selection, settings dialog) SHALL work unchanged
