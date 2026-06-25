## MODIFIED Requirements

### Requirement: JWT anti-tamper check during online license sync

`DeviceStatusSignalRClient.SyncProjectLicenseFromServerAsync()` SHALL, before performing the existing field sync, read the local JWT (from `.urban` file or `LicenseInfo.LatestJwtToken`) as raw text and submit it to the server via `VerifyJwtAsync` for anti-tamper verification. When verification passes, the server SHALL return a **BasePlatform-issued** JWT in `ServerJwt` for the client to adopt.

#### Scenario: Anti-tamper check passes

- **WHEN** `SyncProjectLicenseFromServerAsync` reads the local JWT, submits it via `VerifyJwtAsync`, and receives `Passed = true` with a `ServerJwt` value
- **THEN** SHALL store the `ServerJwt` text to `LicenseInfo.LatestJwtToken`
- **AND** SHALL derive `LicenseInfo` fields from the server JWT claims (`ProId`, `ProName`, **`AccessCode`**, `AuthEndTime`)
- **AND** SHALL overwrite the `LicenseInfo` database record with the derived values
- **AND** MUST NOT 同步或写入 `FdBuildLicenseNo`

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

### Requirement: Server JWT as authoritative source for LicenseInfo

The server-side JWT SHALL be the authoritative source for authorization state. On startup, the client SHALL use the server-provided JWT (stored in `LicenseInfo.LatestJwtToken`) if available; otherwise fall back to the `.urban` file as offline bootstrap. In either case, the JWT claims SHALL be used to overwrite the `LicenseInfo` database record, ensuring database tampering is transient.

#### Scenario: Startup with LatestJwtToken available

- **WHEN** `LicenseInfo.LatestJwtToken` is not null and the JWT passes RS256 signature validation (`iss=BasePlatform`)
- **THEN** SHALL derive authorization state from the `LatestJwtToken` claims
- **AND** SHALL overwrite `LicenseInfo` fields (`ProjectId`, `ProName`, **`AccessCode`**, `AuthEndTime`) from the JWT claims
- **AND** MUST NOT 写入 `FdBuildLicenseNo`

#### Scenario: Startup without LatestJwtToken, .urban file available

- **WHEN** `LicenseInfo.LatestJwtToken` is null and the `.urban` file contains a valid BasePlatform RS256-signed JWT
- **THEN** SHALL use the `.urban` JWT as bootstrap
- **AND** SHALL overwrite `LicenseInfo` fields from the JWT claims
- **AND** SHALL persist the bootstrap JWT text to `LatestJwtToken`

#### Scenario: Database LicenseInfo was tampered but JWT is intact

- **WHEN** `LicenseInfo.AuthEndTime` in the database was manually modified to a future date, but the JWT (from `LatestJwtToken` or `.urban`) is unmodified
- **THEN** on startup, `LicenseInfo.AuthEndTime` SHALL be overwritten with the JWT's `exp` value (the tampered database value is reset)

#### Scenario: User tampered LatestJwtToken JWT text

- **WHEN** `LicenseInfo.LatestJwtToken` was modified to an invalid JWT string (RS256 signature verification fails)
- **THEN** startup SHALL fall back to `.urban` file if available
- **AND** if `.urban` file is also unavailable or invalid, SHALL return `IsSuccess = false`

### Requirement: Hub field sync maps buildLicenseNo to AccessCode

`GetClientProjectLicenseInfo` 返回的 JSON 字段 `buildLicenseNo` SHALL 映射到 `LicenseInfo.AccessCode`。`SyncProjectFieldsFromServerAsync` MUST NOT 接受或同步 `fdBuildLicenseNo` 参数。

#### Scenario: Field sync from server

- **WHEN** `GetClientProjectLicenseInfo` returns `buildLicenseNo`, `proName`, `authEndTime`
- **THEN** SHALL call sync logic with `accessCode` derived from `buildLicenseNo`
- **AND** SHALL update `LicenseInfo.AccessCode`, `ProName`, `AuthEndTime`
- **AND** MUST NOT 更新 `FdBuildLicenseNo`

#### Scenario: JwtAntiTamperResult mapping

- **WHEN** `VerifyJwtAsync` returns `JwtAntiTamperResult` with `BuildLicenseNo` (wire name) and `ServerJwt`
- **THEN** `StoreServerJwtAsync` SHALL persist `ServerJwt` to `LatestJwtToken`
- **AND** SHALL map `BuildLicenseNo` wire value to `LicenseInfo.AccessCode`

## ADDED Requirements

### Requirement: UpdateClientLicense Hub handler

当 UrbanManagement Hub 实现 `UpdateClientLicense` 推送时，客户端 SHALL 注册 SignalR handler：验签 BasePlatform JWT 后调用与 `VerifyJwtAsync` 共用的 `StoreServerJwtAsync` 逻辑。该能力属于 P-Client-3 可选交付阶段，SHALL NOT 阻塞 P-Client-1/2 发版。

#### Scenario: Receive server license push

- **WHEN** Hub invokes `UpdateClientLicense` with a DTO containing BasePlatform JWT
- **THEN** client SHALL validate JWT with `IStaticLicenseChecker`
- **AND** on success SHALL update `LicenseInfo.LatestJwtToken` and derived fields including `AccessCode`

#### Scenario: Invalid pushed JWT ignored

- **WHEN** pushed JWT fails validation
- **THEN** SHALL NOT modify `LicenseInfo`
- **AND** SHALL log a warning
