## 1. Startup authorization result (MaterialClient.Common / Urban)

- [x] 1.1 Add `UrbanStartupAuthorizationResult` record (or equivalent) with `IsAuthorized`, `FailureMessage`, and optional `ProId`
- [x] 1.2 Add `IUrbanStartupAuthorizationService` / implementation registered as singleton via ABP (`ISingletonDependency`)

## 2. Module initialization gate (MaterialClient.Urban)

- [x] 2.1 Refactor `MaterialClientUrbanModule.OnApplicationInitializationAsync`: after JWT check, set startup authorization result on the new service
- [x] 2.2 When authorization is invalid, skip SignalR start and `PollingBackgroundService` registration
- [x] 2.3 When authorization is valid, keep existing `LicenseInfo` write and background service registration unchanged

## 3. Unauthorized notice UI (MaterialClient.Urban)

- [x] 3.1 Add `UnauthorizedNoticeWindow` (or dialog) with primary text 「软件未授权」 and `license.urban` deployment guidance
- [x] 3.2 Show optional secondary detail from `FailureMessage` (e.g. file not found, expired, invalid signature)
- [x] 3.3 On confirm/close, trigger application shutdown only (no main window)

## 4. App startup branching (MaterialClient.Urban)

- [x] 4.1 Update `App.axaml.cs`: after `InitializeAsync`, resolve `IUrbanStartupAuthorizationService`
- [x] 4.2 If unauthorized: show unauthorized notice, call `desktop.Shutdown()`, return without creating `UrbanAttendedWeighingWindow`
- [x] 4.3 If authorized: keep existing main window, ViewModel init, device start, and web host flow

## 5. Verification

- [ ] 5.1 Manual test: no `license.urban`, empty `LicenseInfo` → dialog shown, app exits, no weighing window
- [ ] 5.2 Manual test: valid `license.urban` → main window opens, `LicenseInfo.ProjectId` populated
- [ ] 5.3 Manual test: Debug build without license → same blocking behavior as Release (dialog and exit)
- [x] 5.4 Run `openspec validate add-urban-license-startup-gate --strict`
