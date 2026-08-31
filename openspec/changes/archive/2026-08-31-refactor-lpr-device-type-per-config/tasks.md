## 1. Configuration model

- [x] 1.1 Add `DeviceType` on `LicensePlateRecognitionConfig` and `LicensePlateRecognitionConfigViewModel`; persist in `LicensePlateRecognitionConfigsJson`
- [x] 1.2 Add type-owned backfill (e.g. `ApplyLegacyDeviceType`) for rows missing `DeviceType`; call it on settings load using `SystemSettings.LprDeviceType`; do not assign fields in a new mapping Service
- [x] 1.3 On save, persist each row’s `DeviceType`; optionally echo first valid row into `SystemSettings.LprDeviceType` for old clients only

## 2. Add/Edit LPR UI

- [x] 2.1 Put vendor ComboBox on `AddLprDialog`; bind `DeviceType`; `WhenAnyValue` drives Hikvision/Vzvision field visibility and defaults
- [x] 2.2 Write selected `DeviceType` into dialog Result; edit path opens with that row’s type
- [x] 2.3 Remove the settings-page global LPR vendor ComboBox and `SettingsWindow.axaml.cs` column hiding driven by window-level `LprDeviceType`
- [x] 2.4 Show vendor on the LPR grid (or keep connection columns visible) so mixed vendors are readable
- [x] 2.5 Gate I/O fields in the dialog follow dialog `DeviceType` (Vzvision only), not a global setting

## 3. Runtime per row

- [x] 3.1 `DeviceManagerService` starts Hikvision and/or Vzvision LPR from distinct `DeviceType` values present on valid configs (both may start)
- [x] 3.2 `WeighingCaptureService` resolves `ILprDevice` per row; skip types without active capture
- [x] 3.3 Online checks (`AttendedWeighingViewModel`, `SharedDeviceStatusTracker`, `ILprDeviceOnlineStatusService`) use each row’s `DeviceType`; badge remains any-online
- [x] 3.4 Settings test capture uses the row’s `DeviceType`
- [x] 3.5 `GateIoControlService` gates on the recognizing device’s `DeviceType` (message or matching config), not `SystemSettings.LprDeviceType`

## 4. Tests and verify

- [x] 4.1 Extend `LicensePlateRecognitionConfig` / settings tests for serialize, backfill, and mixed `DeviceType`
- [x] 4.2 Cover DeviceManager start when both Hikvision and Vzvision rows exist (unit or existing test host)
- [ ] 4.3 Manual: add Hikvision and Vzvision rows, save, restart, both listen; old JSON without `DeviceType` still loads
