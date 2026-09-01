## MODIFIED Requirements

### Requirement: JWT anti-tamper check during online license sync

In Release builds, `DeviceStatusSignalRClient.SyncProjectLicenseFromServerAsync()` SHALL, before performing the existing field sync, read the local JWT (from `.urban` file or `LicenseInfo.LatestJwtToken`) as raw text and submit it to the server via `VerifyJwtAsync` for anti-tamper verification. When verification passes, the server SHALL return its freshly signed JWT for the client to adopt. In Debug builds, this authorization sync SHALL be skipped without preventing SignalR connection or non-authorization features.

#### Scenario: Release anti-tamper check passes

- **WHEN** a Release build reads the local JWT, submits it via `VerifyJwtAsync`, and receives `Passed = true` with a `ServerJwt` value
- **THEN** SHALL store the `ServerJwt` text to `LicenseInfo.LatestJwtToken`
- **AND** SHALL derive `LicenseInfo` fields from the server JWT claims (`ProId`, `ProName`, `AccessCode`, `AuthEndTime`)
- **AND** SHALL overwrite the `LicenseInfo` database record with the derived values

#### Scenario: Release anti-tamper check fails with invalid signature

- **WHEN** a Release build receives `Passed = false` with reason indicating signature verification failure
- **THEN** SHALL NOT proceed with the field sync
- **AND** SHALL log a warning indicating the local JWT failed anti-tamper verification
- **AND** SHALL NOT modify the local `LicenseInfo` entity

#### Scenario: Release anti-tamper check fails with expired token

- **WHEN** a Release build receives `Passed = false` with reason indicating the token is expired
- **THEN** SHALL apply the server-authoritative expiration behavior
- **AND** SHALL notify the Urban UI authorization recovery path

#### Scenario: Release anti-tamper check fails with project not found

- **WHEN** a Release build receives `Passed = false` with reason indicating the project was not found on the server
- **THEN** SHALL NOT proceed with the field sync
- **AND** SHALL log a warning indicating the project does not exist

#### Scenario: Release local license is unavailable during sync

- **WHEN** a Release build attempts sync but neither `.urban` file nor `LicenseInfo.LatestJwtToken` is available
- **THEN** SHALL skip the anti-tamper check
- **AND** SHALL proceed with the existing field sync only

#### Scenario: Release SignalR verification call times out

- **WHEN** a Release build's `VerifyJwtAsync` call times out or throws a network exception
- **THEN** SHALL log a warning indicating the verification check was unreachable
- **AND** SHALL fall back to the existing field sync only

#### Scenario: Debug skips online authorization sync

- **WHEN** a Debug build establishes or restores its SignalR connection
- **THEN** SHALL NOT invoke `VerifyJwtAsync`
- **AND** SHALL NOT adopt a server JWT solely from the anti-tamper sync path
- **AND** SHALL continue SignalR device-status, log, approval and other non-authorization behavior

### Requirement: Server JWT as authoritative source for LicenseInfo

In Release builds, the server-side JWT SHALL be the authoritative source for authorization state on startup and after successful anti-tamper sync. On startup, the client SHALL use the server-provided JWT (stored in `LicenseInfo.LatestJwtToken`) if available; otherwise it SHALL fall back to the `.urban` file as offline bootstrap. Validated JWT claims SHALL overwrite the `LicenseInfo` database record. Debug builds follow the same startup JWT validation path (with machineCode relaxation only).

#### Scenario: Release startup with LatestJwtToken available

- **WHEN** a Release build starts and `LicenseInfo.LatestJwtToken` is not null and passes RS256 signature validation
- **THEN** SHALL derive authorization state from the `LatestJwtToken` claims
- **AND** SHALL overwrite `LicenseInfo` fields (`ProjectId`, `ProName`, `AccessCode`, `AuthEndTime`) from the JWT claims

#### Scenario: Release startup without LatestJwtToken

- **WHEN** a Release build starts, `LicenseInfo.LatestJwtToken` is null, and the `.urban` file contains a valid RS256-signed JWT
- **THEN** SHALL use the `.urban` JWT as bootstrap
- **AND** SHALL overwrite `LicenseInfo` fields from the JWT claims

#### Scenario: Release database LicenseInfo was tampered

- **WHEN** a Release build starts with manually modified `LicenseInfo.AuthEndTime` but an intact JWT
- **THEN** `LicenseInfo.AuthEndTime` SHALL be overwritten with the JWT's `exp` value

#### Scenario: Release LatestJwtToken was tampered

- **WHEN** a Release build starts with an invalid `LicenseInfo.LatestJwtToken`
- **THEN** startup SHALL fall back to `.urban` if available
- **AND** if `.urban` is unavailable or invalid, startup authorization SHALL fail

## ADDED Requirements

### Requirement: Debug ignores runtime authorization revocation

MaterialClient.Urban Debug builds MUST NOT interrupt normal program use because an online authorization response or local event reports expiration or device revocation. Release builds SHALL retain the existing recovery and shutdown behavior.

#### Scenario: Debug receives server Expired result

- **WHEN** a Debug build receives or is tested with an authorization-expired result or `LicenseExpiredEto`
- **THEN** SHALL NOT show the activation window
- **AND** SHALL NOT shut down or restart the application

#### Scenario: Debug receives server DeviceChanged result

- **WHEN** a Debug build receives or is tested with a device-changed result or `LicenseDeviceRevokedEto`
- **THEN** SHALL NOT show the activation window
- **AND** SHALL NOT shut down or restart the application

#### Scenario: Release receives runtime revocation

- **WHEN** a Release build receives an Expired or DeviceChanged authorization result
- **THEN** SHALL preserve the existing token clearing, recovery prompt, restart-on-success and shutdown-on-cancel behavior
