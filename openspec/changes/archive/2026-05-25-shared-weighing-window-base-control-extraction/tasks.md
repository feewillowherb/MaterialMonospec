## 1. Create WeighingWindowBase Control

- [x] 1.1 Create `MaterialClient.UI/Controls/WeighingWindowBase.axaml` with 4-row Grid layout: header bar (Row 0, PrimaryBlue), WeightAreaContent ContentPresenter (Row 1), MainContent ContentPresenter (Row 2), DeviceStatusBar region (Row 3)
- [x] 1.2 Create header bar 3-column Grid inside Row 0: HeaderLeftContent slot (Col 0), MenuItems slot (Col 1), minimize/close buttons with titlebar style classes (Col 2)
- [x] 1.3 Create `WeighingWindowBase.axaml.cs` code-behind with dependency properties: `HeaderLeftContent`, `MenuItems`, `WeightAreaContent`, `MainContent`, `DeviceStatuses`, `CameraStatusDetails`
- [x] 1.4 Add routed events for MinimizeButtonClick, CloseButtonClick, and TitleBarPointerPressed so host Windows can subscribe
- [x] 1.5 Add DeviceStatusBar element in Row 3 bound to the `DeviceStatuses` and `CameraStatusDetails` DPs
- [x] 1.6 Verify MaterialClient.UI project builds without errors

## 2. Refactor AttendedWeighingWindow

- [x] 2.1 Replace the Window's inner content with `<Panel><ui:WeighingWindowBase .../><ursa:OverlayDialogHost/></Panel>` wrapper
- [x] 2.2 Move the logo Image into WeighingWindowBase.HeaderLeftContent
- [x] 2.3 Move the 5 menu buttons + DataManagement Popup into WeighingWindowBase.MenuItems, preserving PlacementTarget binding on the Popup
- [x] 2.4 Move the blue gradient weight display area (delivery-type selector, weight TextBlock, plate Border, status/loading) into WeighingWindowBase.WeightAreaContent
- [x] 2.5 Move the 3-column main grid (WeighingRecordListView, AttendedWeighingMainView/DetailView, camera+bill area) into WeighingWindowBase.MainContent
- [x] 2.6 Bind DeviceStatuses and CameraStatusDetails DPs to the ViewModel properties
- [x] 2.7 Update code-behind: subscribe to WeighingWindowBase routed events for minimize/close/titlebar-drag; keep Popup and dialog management logic unchanged
- [x] 2.8 Verify the refactored AttendedWeighingWindow builds and renders identically to the original

## 3. Refactor UrbanAttendedWeighingWindow

- [x] 3.1 Replace the Window's ContentGrid with a Grid containing WeighingWindowBase and resize grip Borders as siblings
- [x] 3.2 Move the "凡" logo Border and title TextBlocks into WeighingWindowBase.HeaderLeftContent
- [x] 3.3 Move the single "系统设置" button into WeighingWindowBase.MenuItems
- [x] 3.4 Move the weight display (TextBlock + status) into WeighingWindowBase.WeightAreaContent
- [x] 3.5 Move the 2-column main grid (vehicle records + photo sidebar) into WeighingWindowBase.MainContent
- [x] 3.6 Bind DeviceStatuses DP to the ViewModel property; keep CameraStatusDetails unbound (Urban doesn't use it)
- [x] 3.7 Update code-behind: subscribe to WeighingWindowBase routed events for minimize/close/titlebar-drag; keep tab click, record selection, and settings dialog logic unchanged
- [x] 3.8 Ensure all 8 resize grip Borders remain outside WeighingWindowBase at the Window root Grid level
- [x] 3.9 Verify the refactored UrbanAttendedWeighingWindow builds and renders correctly (header normalized to PrimaryBlue)
