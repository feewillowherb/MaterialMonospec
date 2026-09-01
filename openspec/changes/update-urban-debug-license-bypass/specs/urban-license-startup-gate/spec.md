## MODIFIED Requirements

### Requirement: Startup blocks when authorization is invalid

MaterialClient.Urban SHALL select startup authorization behavior by compile configuration before presenting the weighing main window. In Release builds, authorization SHALL be considered valid only when startup JWT validation succeeds via `IStaticLicenseChecker` and yields a non-empty `ProId` in `LicenseCheckResult`; invalid authorization MUST block the main window and normal services. In Debug builds, the application SHALL use the Debug development authorization context and MUST NOT block startup because local license data is invalid.

#### Scenario: Valid JWT with ProId allows Release startup

- **WHEN** a Release build starts and startup JWT validation succeeds from `LatestJwtToken` or `license.urban`
- **AND** `LicenseCheckResult.ProId` is a non-empty GUID
- **THEN** SHALL write or update `LicenseInfo` as today
- **AND** SHALL open `UrbanAttendedWeighingWindow` and continue the normal startup sequence

#### Scenario: Missing license file and no LatestJwtToken blocks Release startup

- **WHEN** a Release build starts
- **AND** `LicenseInfo.LatestJwtToken` is null or empty
- **AND** the configured license file (default `license.urban`) does not exist or is invalid
- **THEN** startup authorization SHALL be invalid
- **AND** SHALL NOT open the weighing main window
- **AND** SHALL show the unauthorized notice to the user
- **AND** SHALL exit the application after the user confirms the notice

#### Scenario: JWT validation failure blocks Release startup

- **WHEN** a Release build starts
- **AND** JWT signature validation fails, the token is expired, `proId` is missing or invalid, or machineCode does not match
- **THEN** startup authorization SHALL be invalid
- **AND** SHALL NOT write or update `LicenseInfo` from the invalid token
- **AND** SHALL show the unauthorized notice and exit as above

#### Scenario: Debug startup bypasses all local license failures

- **WHEN** a Debug build starts with a missing, empty, malformed, incorrectly signed, expired, claim-incomplete, or machineCode-mismatched license
- **OR** the existing `LicenseInfo` record reports an expired authorization
- **THEN** startup authorization SHALL succeed using the Debug development authorization context
- **AND** SHALL NOT invoke online activation recovery
- **AND** SHALL open `UrbanAttendedWeighingWindow`
- **AND** SHALL start the same main-window, device, diagnostic-host and background-service sequence as an authorized startup

#### Scenario: Release cannot enable the Debug bypass

- **WHEN** a Release build receives any configuration value, environment variable, local database value or diagnostic request intended to enable the Debug bypass
- **THEN** the bypass MUST remain unavailable
- **AND** invalid authorization MUST continue to block startup

### Requirement: Unauthorized notice dialog

When startup authorization is invalid in a Release build, MaterialClient.Urban SHALL display a modal notice to the user before exit. The notice MUST use user-facing Chinese text indicating the software is not authorized. The notice SHALL instruct the user to obtain a valid Urban license file (`license.urban`) and place it in the application directory, then restart. The notice MAY include the technical failure message from `LicenseCheckResult.Message` as secondary detail. Debug development authorization MUST NOT display this notice solely because local license data is invalid.

#### Scenario: Release user sees unauthorized message

- **WHEN** Release startup authorization is invalid
- **THEN** SHALL display a dialog with a title or primary message equivalent to 「软件未授权」
- **AND** SHALL include guidance to deploy `license.urban`
- **AND** SHALL NOT display the weighing main interface behind the dialog

#### Scenario: Release user confirms and application exits

- **WHEN** the user dismisses the Release unauthorized notice
- **THEN** SHALL call application shutdown
- **AND** SHALL NOT start SignalR client, polling upload worker, or device services for weighing

#### Scenario: Debug invalid license does not show unauthorized notice

- **WHEN** a Debug build uses the development authorization context because local license data is invalid
- **THEN** SHALL NOT open the unauthorized or online activation window
- **AND** SHALL proceed directly to the weighing main interface

## ADDED Requirements

### Requirement: Debug development authorization context

MaterialClient.Urban Debug builds SHALL provide a single canonical development authorization context containing a non-empty `ProjectId`, `ProName`, `AccessCode`, future `AuthEndTime`, and the current value from `IMachineCodeService.GetMachineCode()`. The context SHALL be compiled out of Release builds and SHALL NOT treat claims from an invalid license as trusted data.

#### Scenario: Debug starts with an unparseable license

- **WHEN** a Debug build cannot parse any local license into trusted claims
- **THEN** SHALL create or update `LicenseInfo` from the canonical development authorization context
- **AND** dependent services SHALL be able to read non-empty project and access-code fields
- **AND** SHALL NOT persist the unparseable token as a validated `LatestJwtToken`

#### Scenario: Release artifact excludes development authorization

- **WHEN** MaterialClient.Urban is compiled in Release configuration
- **THEN** the development authorization path MUST NOT be callable
- **AND** Release startup SHALL derive authorization only from the existing strict license flow
