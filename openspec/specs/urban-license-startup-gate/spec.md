# Urban License Startup Gate Specification

## Purpose

定义 MaterialClient.Urban 启动时 JWT 授权门禁：无有效 `ProId` 时阻塞进入称重主界面，并向用户展示未授权提示。
## Requirements
### Requirement: Startup blocks when authorization is invalid

MaterialClient.Urban SHALL validate startup authorization via `TryExecuteStartupLicenseCheckAsync` in both Debug and Release builds before presenting the weighing main window. Authorization SHALL be considered valid only when startup JWT validation succeeds via `IStaticLicenseChecker` and yields a non-empty `ProId` in `LicenseCheckResult`, except that Debug builds MAY skip JWT `machineCode` claim mismatch while still requiring a valid RS256-signed, non-expired token with required claims. Invalid authorization MUST block the main window and normal services in Release; Debug follows the same gate except for the machineCode relaxation.

Pipeline and local diagnostics SHALL prepare authorization data before startup using `Invoke-UrbanLicenseSeed` / `UpsertLicenseInfo` (writing `license.urban` and SQLite `LicenseInfo`), optionally selecting different `seeds/*.json` per project.

#### Scenario: Valid JWT with ProId allows startup

- **WHEN** MaterialClient.Urban starts and startup JWT validation succeeds from `LatestJwtToken` or `license.urban`
- **AND** `LicenseCheckResult.ProId` is a non-empty GUID
- **THEN** SHALL write or update `LicenseInfo` as today
- **AND** SHALL open `UrbanAttendedWeighingWindow` and continue the normal startup sequence

#### Scenario: Missing license file and no LatestJwtToken blocks startup

- **WHEN** MaterialClient.Urban starts
- **AND** `LicenseInfo.LatestJwtToken` is null or empty
- **AND** the configured license file (default `license.urban`) does not exist or is invalid
- **THEN** startup authorization SHALL be invalid
- **AND** SHALL NOT open the weighing main window
- **AND** SHALL show the unauthorized notice to the user
- **AND** SHALL exit the application after the user confirms the notice

#### Scenario: JWT validation failure blocks startup

- **WHEN** MaterialClient.Urban starts
- **AND** JWT signature validation fails, the token is expired, or `proId` is missing or invalid
- **THEN** startup authorization SHALL be invalid
- **AND** SHALL NOT write or update `LicenseInfo` from the invalid token
- **AND** SHALL show the unauthorized notice and exit as above

#### Scenario: Release machineCode mismatch blocks startup

- **WHEN** a Release build starts with a JWT whose `machineCode` claim does not match the local machine code
- **THEN** startup authorization SHALL be invalid

#### Scenario: Debug machineCode mismatch is tolerated

- **WHEN** a Debug build starts with an otherwise valid JWT whose `machineCode` claim does not match the local machine code
- **THEN** startup authorization SHALL succeed
- **AND** SHALL open `UrbanAttendedWeighingWindow`

#### Scenario: Pipeline seeds license before probe

- **WHEN** an Urban pipeline start script runs `Invoke-UrbanLicenseSeed` in Local mode before launching the app
- **THEN** SHALL write `license.urban` and upsert `LicenseInfo` via `UpsertLicenseInfo`
- **AND** MAY patch the seed JSON `machineCode` to the local machine before upsert

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

