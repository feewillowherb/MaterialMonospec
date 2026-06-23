# JWT Anti-Tamper Sync Integration

## Purpose

Provides client-side JWT anti-tamper verification integration with the online license synchronization flow in MaterialClient. This capability ensures that license information remains synchronized with the authoritative server source and that local license tampering is detected and corrected by validating JWT signatures and overwriting local database state with server-verified JWT claims.

## Requirements

### Requirement: JWT anti-tamper check during online license sync

`DeviceStatusSignalRClient.SyncProjectLicenseFromServerAsync()` SHALL, before performing the existing field sync, read the local JWT (from `.urban` file or `LicenseInfo.LatestJwtToken`) as raw text and submit it to the server via `VerifyJwtAsync` for anti-tamper verification. When verification passes, the server SHALL return its freshly signed JWT for the client to adopt.

#### Scenario: Anti-tamper check passes

- **WHEN** `SyncProjectLicenseFromServerAsync` reads the local JWT, submits it via `VerifyJwtAsync`, and receives `Passed = true` with a `ServerJwt` value
- **THEN** SHALL store the `ServerJwt` text to `LicenseInfo.LatestJwtToken`
- **AND** SHALL derive `LicenseInfo` fields from the server JWT claims (ProId, ProName, BuildLicenseNo, FdBuildLicenseNo, AuthEndTime)
- **AND** SHALL overwrite the `LicenseInfo` database record with the derived values

#### Scenario: Anti-tamper check fails with invalid signature

- **WHEN** `VerifyJwtAsync` returns `Passed = false` with reason indicating signature verification failure
- **THEN** SHALL NOT proceed with the field sync
- **AND** SHALL log a warning indicating the local JWT failed anti-tamper verification
- **AND** SHALL NOT modify the local `LicenseInfo` entity

#### Scenario: Anti-tamper check fails with expired token

- **WHEN** `VerifyJwtAsync` returns `Passed = false` with reason indicating the token is expired
- **THEN** SHALL NOT proceed with the field sync
- **AND** SHALL log a warning indicating the JWT is expired

#### Scenario: Anti-tamper check fails with project not found

- **WHEN** `VerifyJwtAsync` returns `Passed = false` with reason indicating the project was not found on the server
- **THEN** SHALL NOT proceed with the field sync
- **AND** SHALL log a warning indicating the project does not exist

#### Scenario: Local .urban file does not exist and no LatestJwtToken during sync

- **WHEN** `SyncProjectLicenseFromServerAsync` attempts to read the local JWT but neither `.urban` file nor `LicenseInfo.LatestJwtToken` is available
- **THEN** SHALL skip the anti-tamper check
- **AND** SHALL proceed with the existing field sync only (no JWT to compare)

#### Scenario: SignalR verification call times out

- **WHEN** the `VerifyJwtAsync` SignalR call times out or throws a network exception
- **THEN** SHALL log a warning indicating the verification check was unreachable
- **AND** SHALL fall back to the existing field sync only (availability over strict verification)

### Requirement: JWT raw text reading for sync

The sync flow SHALL read the JWT as a raw string. The source priority SHALL be: `LicenseInfo.LatestJwtToken` (if non-null) first, then the `.urban` file from `SystemSettings.LicenseFilePath`. The raw text SHALL be passed directly to the SignalR `VerifyJwtAsync` method.

#### Scenario: LatestJwtToken available in DB

- **WHEN** `LicenseInfo.LatestJwtToken` is not null and not empty
- **THEN** the `LatestJwtToken` value SHALL be used as the JWT text for `VerifyJwtAsync`

#### Scenario: LatestJwtToken empty, .urban file exists

- **WHEN** `LicenseInfo.LatestJwtToken` is null or empty, and the `.urban` file exists
- **THEN** the `.urban` file content SHALL be used as the JWT text for `VerifyJwtAsync`

#### Scenario: Empty or whitespace-only file

- **WHEN** the `.urban` file exists but is empty or contains only whitespace
- **THEN** the anti-tamper check SHALL be skipped
- **AND** SHALL proceed with existing field sync only

### Requirement: Server JWT as authoritative source for LicenseInfo

The server-side JWT SHALL be the authoritative source for authorization state. On startup, the client SHALL use the server-provided JWT (stored in `LicenseInfo.LatestJwtToken`) if available; otherwise fall back to the `.urban` file as offline bootstrap. In either case, the JWT claims SHALL be used to overwrite the `LicenseInfo` database record, ensuring database tampering is transient.

#### Scenario: Startup with LatestJwtToken available

- **WHEN** `LicenseInfo.LatestJwtToken` is not null and the JWT passes RS256 signature validation
- **THEN** SHALL derive authorization state from the `LatestJwtToken` claims
- **AND** SHALL overwrite `LicenseInfo` fields (ProjectId, ProName, BuildLicenseNo, FdBuildLicenseNo, AuthEndTime) from the JWT claims

#### Scenario: Startup without LatestJwtToken, .urban file available

- **WHEN** `LicenseInfo.LatestJwtToken` is null and the `.urban` file contains a valid RS256-signed JWT
- **THEN** SHALL use the `.urban` JWT as bootstrap
- **AND** SHALL overwrite `LicenseInfo` fields from the JWT claims

#### Scenario: Database LicenseInfo was tampered but JWT is intact

- **WHEN** `LicenseInfo.AuthEndTime` in the database was manually modified to a future date, but the JWT (from `LatestJwtToken` or `.urban`) is unmodified
- **THEN** on startup, `LicenseInfo.AuthEndTime` SHALL be overwritten with the JWT's `exp` value (the tampered database value is reset)

#### Scenario: User tampered LatestJwtToken JWT text

- **WHEN** `LicenseInfo.LatestJwtToken` was modified to an invalid JWT string (RS256 signature verification fails)
- **THEN** startup SHALL fall back to `.urban` file if available
- **AND** if `.urban` file is also unavailable or invalid, SHALL return `IsSuccess = false`
