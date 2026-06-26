# Urban License Startup Gate Specification

## Purpose

定义 MaterialClient.Urban 启动时 JWT 授权门禁：无有效 `ProId` 时阻塞进入称重主界面，并向用户展示未授权提示。
## Requirements
### Requirement: Startup blocks when authorization is invalid

MaterialClient.Urban SHALL evaluate authorization during ABP application initialization before presenting the weighing main window. Authorization SHALL be considered valid only when startup JWT validation succeeds via `IStaticLicenseChecker` (**BasePlatform issuer**, `accessCode` and `machineCode` claims) and yields a non-empty `ProId` in `LicenseCheckResult`. When authorization is invalid, the application MUST NOT open `UrbanAttendedWeighingWindow`, MUST NOT start the attended weighing pipeline or hardware device manager, and MUST exit after the user dismisses the unauthorized notice.

#### Scenario: Valid JWT with ProId allows startup

- **WHEN** startup JWT validation succeeds from `LatestJwtToken` or `license.urban`
- **AND** `LicenseCheckResult.ProId` is a non-empty GUID
- **THEN** SHALL write or update `LicenseInfo` including `AccessCode` and `LatestJwtToken` when bootstrapped from file
- **AND** SHALL open `UrbanAttendedWeighingWindow` and continue the normal startup sequence

#### Scenario: Missing license file and no LatestJwtToken blocks startup

- **WHEN** `LicenseInfo.LatestJwtToken` is null or empty
- **AND** the configured license file (default `license.urban`) does not exist or is invalid
- **THEN** startup authorization SHALL be invalid
- **AND** SHALL NOT open the weighing main window
- **AND** SHALL show the unauthorized notice to the user
- **AND** SHALL exit the application after the user confirms the notice

#### Scenario: JWT validation failure blocks startup

- **WHEN** JWT signature validation fails, the token is expired, `iss` is not `BasePlatform`, `machineCode` mismatches, `accessCode` is missing, or `proId` claim is missing or invalid
- **THEN** startup authorization SHALL be invalid
- **AND** SHALL NOT write or update `LicenseInfo`
- **AND** SHALL show the unauthorized notice and exit as above

#### Scenario: All build configurations enforce the gate

- **WHEN** startup authorization is invalid
- **THEN** invalid startup authorization MUST block the main window in both Debug and Release builds
- **AND** MUST NOT provide a configuration flag or compile-time bypass

### Requirement: Unauthorized notice dialog

When startup authorization is invalid, MaterialClient.Urban SHALL display a modal notice to the user before exit. The notice MUST use user-facing Chinese text indicating the software is not authorized. The notice SHALL instruct the user to obtain a valid Urban license file (`license.urban`) and place it in the application directory, then restart. The notice MAY include the technical failure message from `LicenseCheckResult.Message` as secondary detail.

#### Scenario: User sees unauthorized message

- **WHEN** startup authorization is invalid
- **THEN** SHALL display a dialog with a title or primary message equivalent to 「软件未授权」
- **AND** SHALL include guidance to deploy `license.urban`
- **AND** SHALL NOT display the weighing main interface behind the dialog

#### Scenario: User confirms and application exits

- **WHEN** the user dismisses the unauthorized notice
- **THEN** SHALL call application shutdown
- **AND** SHALL NOT start SignalR client, polling upload worker, or device services for weighing

### Requirement: Startup authorization result exposed to App layer

The authorization outcome from `MaterialClientUrbanModule` initialization SHALL be available to `App.axaml.cs` through an injectable service or equivalent ABP-registered singleton so the UI layer can branch without duplicating JWT validation logic.

#### Scenario: App reads module authorization result

- **WHEN** `AbpApplication.InitializeAsync` completes
- **THEN** `App.axaml.cs` SHALL read whether startup authorization succeeded
- **AND** SHALL branch to main window or unauthorized notice based on that result only

### Requirement: Bootstrap from license.urban writes LatestJwtToken

When startup authorization succeeds by reading `license.urban` (because `LatestJwtToken` was empty or invalid), the module SHALL persist the JWT text to `LicenseInfo.LatestJwtToken` so subsequent starts and SignalR sync use the same authoritative token.

#### Scenario: First bootstrap from file

- **WHEN** `LatestJwtToken` is empty and `license.urban` contains a valid BasePlatform JWT
- **THEN** startup SHALL succeed
- **AND** SHALL write the file JWT content to `LicenseInfo.LatestJwtToken`
- **AND** SHALL persist `AccessCode` and other claims to `LicenseInfo`

#### Scenario: Subsequent start uses LatestJwtToken

- **WHEN** `LicenseInfo.LatestJwtToken` is populated from a prior bootstrap
- **THEN** startup SHALL prefer `LatestJwtToken` over re-reading the file
- **AND** SHALL NOT require `license.urban` to exist if `LatestJwtToken` is valid

