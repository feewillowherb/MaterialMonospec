## 1. Apply Setup

- [x] 1.1 In `repos/MaterialClient`, create and switch to branch `update-urban-debug-license-bypass` from `origin/main` before the first product-code edit
- [x] 1.2 Add a Debug-only canonical Urban development authorization record/static source with the fixed demo `ProjectId`, `ProName`, `AccessCode` and future `AuthEndTime`; obtain machineCode from the existing `IMachineCodeService`, do not register the pure data source in DI, and do not include a bypass switch in Release configuration

## 2. Debug Startup Authorization

- [x] 2.1 Add a type-owned `LicenseInfo` operation that creates/applies the Debug development authorization fields without accepting claims from an invalid JWT
- [x] 2.2 Update `MaterialClientUrbanModule` so Debug startup establishes and persists the development authorization context before any database-expiry or JWT checks, while Release continues through `TryExecuteStartupLicenseCheckAsync`
- [x] 2.3 Ensure Debug startup returns an authorized `UrbanStartupAuthorizationResult`, skips `UrbanLicenseRecoveryService`, and proceeds with the existing main window, device, MinimalWebHost, SignalR and background-service startup sequence
- [x] 2.4 Keep `IStaticLicenseChecker` strict and unchanged for Release and independent callers; remove or avoid any runtime configuration/environment-variable authorization bypass

## 3. Debug Runtime Authorization

- [x] 3.1 Make `DeviceStatusSignalRClient` skip `VerifyJwtAsync`, server JWT adoption and authorization field synchronization in Debug while preserving SignalR non-authorization behavior
- [x] 3.2 Make `LicenseExpiredEventHandler` and `LicenseDeviceRevokedEventHandler` ignore authorization recovery/restart/shutdown behavior in Debug, while retaining the existing Release behavior
- [x] 3.3 Add clear warning logs when the Debug startup or runtime authorization bypass is active, without logging JWT text or other secrets

## 4. Automated Verification

- [x] 4.1 Replace the skipped `StaticLicenseCheckerTests` coverage needed to prove the strict checker still rejects missing, malformed, expired, invalid-signature, missing-claim and machineCode-mismatched tokens
- [x] 4.2 Add Debug startup tests covering no license, invalid token, expired database row and machineCode mismatch; assert a complete development `LicenseInfo`, authorized result, and no activation recovery
- [x] 4.3 Add Debug runtime tests proving online JWT verification is not invoked and Expired/DeviceChanged events do not hide the main window or terminate/restart the application
- [x] 4.4 Add Release-path tests proving invalid startup authorization remains blocked and runtime Expired/DeviceChanged handling still clears/requires recovery as before
- [x] 4.5 Build `MaterialClient.Urban` in both Debug and Release using the repository `.build-verify/` output convention and run the targeted authorization test suite

## 5. Pipeline and Documentation

- [x] 5.1 Update `pipelines/graphs/urban/urban-passage-probe` startup guidance so Debug runs no longer claim to require a valid local license, while explicitly stating Release remains strict
- [x] 5.2 Run `openspec validate update-urban-debug-license-bypass --strict` and record any manual Debug smoke-test evidence without declaring pipeline L3 acceptance

### Verification notes (5.2)

- `openspec validate update-urban-debug-license-bypass --strict` → valid
- Debug: `MaterialClient.Urban` build to `.build-verify/`; Common auth tests 18 passed; Urban Debug auth tests 5 passed
- Release: `MaterialClient.Urban` build to `.build-verify/`; Common auth tests 18 passed; Urban Release auth tests 2 passed
- Manual Debug UI smoke / pipeline L2–L3: **not claimed** (Agent must not declare L3)
