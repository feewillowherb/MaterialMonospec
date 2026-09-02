## 1. Apply Setup

- [x] 1.1 In `repos/MaterialClient`, create and switch to branch `update-urban-debug-license-bypass` from `origin/main` before the first product-code edit

## 2. Remove UrbanDebugDevelopmentAuthorization

- [x] 2.1 Delete `UrbanDebugDevelopmentAuthorization.cs` and Debug startup bypass in `MaterialClientUrbanModule` (unified `TryExecuteStartupLicenseCheckAsync`)
- [x] 2.2 Remove `LicenseInfo.CreateDebugDevelopmentAuthorization` / `ApplyDebugDevelopmentAuthorization`
- [x] 2.3 Add Debug-only JWT machineCode mismatch tolerance in `StaticLicenseChecker` (Release strict)

## 3. Pipeline UpsertLicenseInfo path

- [x] 3.1 Enhance `Invoke-UrbanLicenseSeed` to patch local `machineCode` before `UpsertLicenseInfo`; support `-SeedRelPath` for project switching
- [x] 3.2 Update `Start-UrbanForProbe.ps1` to seed license by default (remove Debug skip); pass `-SeedRelPath`
- [x] 3.3 Retire `urban-debug-license-bypass` to `graphs/_retired/2026-09/`; update `urban-passage-probe` docs and `pipelines/AGENTS.md`

## 4. Debug Runtime Authorization (retained)

- [x] 4.1 Keep `DeviceStatusSignalRClient` Debug skip of `VerifyJwtAsync`
- [x] 4.2 Keep Debug no-op on `LicenseExpiredEventHandler` / `LicenseDeviceRevokedEventHandler`

## 5. Automated Verification

- [x] 5.1 Update/remove tests tied to `UrbanDebugDevelopmentAuthorization` and `LicenseInfo` debug methods
- [x] 5.2 Adjust `StaticLicenseCheckerTests` for Debug machineCode tolerance
- [x] 5.3 Build `MaterialClient.Urban` Debug/Release and run targeted auth tests

## 6. OpenSpec

- [x] 6.1 Update `proposal.md` / `design.md` to reflect UpsertLicenseInfo approach
- [x] 6.2 Run `openspec validate update-urban-debug-license-bypass --strict`
