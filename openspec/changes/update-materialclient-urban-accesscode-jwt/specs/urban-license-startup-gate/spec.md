## MODIFIED Requirements

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
