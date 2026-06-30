# JWT Anti-Tamper Service

## Purpose

Provides server-side JWT anti-tamper verification capabilities for the UrbanManagement system. This service enables MaterialClient instances to verify the authenticity of their local JWT tokens against the authoritative source (GovProject data) and receive freshly signed JWTs, preventing license tampering and ensuring authorization state consistency.

## Requirements

### Requirement: JWT anti-tamper verification service

`IJwtAntiTamperService` SHALL define a `VerifyAndCompareAsync(string jwtToken, Guid proId)` method that validates the submitted JWT token using RS256 signature verification (with BasePlatform public key), extracts the `proId` claim, queries the `GovProject` by that `proId`, and if the project exists and the JWT is valid, retrieves a freshly signed JWT from BasePlatform API (`/api/auth/license-file`). The method SHALL return a `JwtAntiTamperResult`.

#### Scenario: Valid JWT with matching project

- **WHEN** `VerifyAndCompareAsync` is called with a JWT that has a valid RS256 signature, correct issuer (`BasePlatform`) and audience (`MaterialClient.Urban`), and the `proId` claim matches an existing `GovProject` record
- **THEN** SHALL return `JwtAntiTamperResult` with `Passed = true`
- **AND** `ServerJwt` SHALL contain a freshly signed JWT retrieved from BasePlatform API (NOT locally re-signed)
- **AND** `ProName`, `BuildLicenseNo` (from `AccessCode`), `FdBuildLicenseNo`, `AuthEndTime` SHALL be populated from the `GovProject` fields
- **AND** the system SHALL call `IBasePlatformAuthHttpClient.GetLicenseFileAsync` with ProductCode=5001

#### Scenario: Invalid RS256 signature

- **WHEN** `VerifyAndCompareAsync` is called with a JWT whose RS256 signature does not verify against the configured RSA public key (BasePlatform public key)
- **THEN** SHALL return `JwtAntiTamperResult` with `Passed = false` and `Reason` indicating signature verification failure
- **AND** the system SHALL NOT attempt to call BasePlatform API

#### Scenario: No GovProject found for proId

- **WHEN** `VerifyAndCompareAsync` is called with a validly-signed JWT but no `GovProject` record exists for the `proId` extracted from the JWT claims
- **THEN** SHALL return `JwtAntiTamperResult` with `Passed = false` and `Reason` indicating the project was not found on the server
- **AND** the system SHALL NOT attempt to call BasePlatform API

#### Scenario: Expired JWT submitted

- **WHEN** `VerifyAndCompareAsync` is called with a JWT whose `exp` claim is in the past (beyond clock skew tolerance)
- **THEN** SHALL return `JwtAntiTamperResult` with `Passed = false` and `Reason` indicating the token is expired
- **AND** the system SHALL NOT attempt to call BasePlatform API

#### Scenario: BasePlatform API call failure

- **WHEN** `VerifyAndCompareAsync` successfully validates the JWT but the call to BasePlatform `/api/auth/license-file` fails (network error, 5xx, etc.)
- **THEN** SHALL return `JwtAntiTamperResult` with `Passed = false` and `Reason` indicating "无法获取授权令牌，请稍后重试"
- **AND** the system SHALL log the error with ProId and exception details
- **AND** the system SHALL NOT fall back to local JWT signing

### Requirement: SignalR Hub JWT verification endpoint

`DeviceStatusHub` SHALL expose a `VerifyJwtAsync(string jwtToken, string proId)` hub method that calls `IJwtAntiTamperService.VerifyAndCompareAsync` and returns the `JwtAntiTamperResult`. The `proId` parameter SHALL be parsed as a Guid; if parsing fails, the method SHALL return a fail result.

#### Scenario: Valid request via SignalR

- **WHEN** a connected client invokes `VerifyJwtAsync` with a JWT string and a valid GUID string as proId
- **THEN** SHALL return the `JwtAntiTamperResult` from the anti-tamper service
- **AND** if passed, `ServerJwt` SHALL contain BasePlatform-signed JWT (not locally signed)

#### Scenario: Invalid proId format

- **WHEN** a client invokes `VerifyJwtAsync` with a proId string that is not a valid GUID
- **THEN** SHALL return `JwtAntiTamperResult` with `Passed = false` and `Reason` indicating invalid ProId format
- **AND** the system SHALL NOT attempt to call BasePlatform API

### Requirement: 提交 JWT 的 machineCode 设备绑定校验

`JwtAntiTamperService.VerifyAndCompareAsync` SHALL 在 RS256 验签通过、查询到 `GovProject` 之后、调用 BasePlatform 获取新 JWT 之前，提取**提交 JWT 的 `machineCode` claim** 并与 `GovProject.MachineCode`（权威机器码）比对。两者不一致时 SHALL 返回 `Passed = false` 并以 `DEVICE_CHANGED` 标记原因，表明授权设备已变更。

#### Scenario: machineCode 一致正常通过

- **WHEN** 提交 JWT 的 `machineCode` claim 与 `GovProject.MachineCode` 一致
- **THEN** SHALL 继续既有流程（调用 BasePlatform 获取新 JWT）
- **AND** SHALL 返回 `Passed = true`、`ServerJwt` 为 BasePlatform 新签发 JWT

#### Scenario: machineCode 不一致返回设备变更失败

- **WHEN** 提交 JWT 的 `machineCode` claim 与 `GovProject.MachineCode` 不一致（如旧设备在跨设备重新激活后连接）
- **THEN** SHALL 返回 `Passed = false`
- **AND** `Reason` SHALL 标记设备变更（如 `DEVICE_CHANGED:授权设备已变更，请在当前设备重新激活`）
- **AND** `RevocationReason` SHALL 标记为设备变更类型
- **AND** SHALL NOT 调用 BasePlatform API 获取新 JWT
- **AND** `ServerJwt` SHALL 为 null

#### Scenario: 提交 JWT 缺少 machineCode claim

- **WHEN** 提交 JWT 通过签名验证但不含 `machineCode` claim
- **THEN** SHALL 返回 `Passed = false`，`Reason` 指示令牌缺少设备绑定信息
- **AND** SHALL NOT 调用 BasePlatform API

### Requirement: JwtAntiTamperResult DTO

`JwtAntiTamperResult` SHALL be a DTO with the following properties: `Passed` (bool), `Reason` (string?, null when passed), `ServerJwt` (string?, the JWT retrieved from BasePlatform when passed), `ProName` (string?), `BuildLicenseNo` (string?, from `GovProject.AccessCode`), `FdBuildLicenseNo` (string?), `AuthEndTime` (DateTime?), `RevocationReason` (enum/string?, for distinguishing failure types such as `DEVICE_CHANGED`, `EXPIRED`, `NOT_FOUND`, `INVALID_SIGNATURE`). The `ServerJwt` and license fields SHALL only be populated when `Passed = true`.

#### Scenario: Result with BasePlatform JWT
- **WHEN** `JwtAntiTamperResult` is constructed with `Passed = true`
- **THEN** `ServerJwt` SHALL contain the JWT text retrieved from BasePlatform API
- **AND** `BuildLicenseNo` SHALL contain `GovProject.AccessCode` value
- **AND** `FdBuildLicenseNo` SHALL contain `GovProject.FdBuildLicenseNo` value
- **AND** `ProName` SHALL contain `GovProject.ProName` value
- **AND** `AuthEndTime` SHALL contain `GovProject.AuthEndTime` value

#### Scenario: Device change failure result
- **WHEN** `Passed = false` due to machineCode mismatch
- **THEN** `RevocationReason` SHALL be `DEVICE_CHANGED`
- **AND** `Reason` SHALL contain user-facing Chinese message
- **AND** `ServerJwt` SHALL be null

### Requirement: Local JWT re-signing
**Reason**: Replaced by delegating JWT signing to BasePlatform for unified authorization management
**Migration**: All code that relies on `UrbanLicenseGenerator` for local JWT signing SHALL be updated to call BasePlatform API instead. The `UrbanLicenseGenerator` class SHALL be marked as `[Obsolete]` or removed entirely.

#### Scenario: Old local signing removed
- **WHEN** `JwtAntiTamperService` successfully verifies a client JWT
- **THEN** the system SHALL NOT call `UrbanLicenseGenerator.GenerateLicenseToken`
- **AND** the system SHALL NOT use local RSA private key for signing
- **AND** the system SHALL retrieve JWT from BasePlatform API instead

### Requirement: UrbanManagement as JWT issuer
**Reason**: JWT issuing authority moved to BasePlatform for centralized authorization control
**Migration**: All JWT validation logic SHALL be updated to accept `iss = "BasePlatform"` instead of `iss = "UrbanManagement"`. The `Jwt:PublicKey` configuration SHALL be updated to contain BasePlatform public key (not UrbanManagement private key).

#### Scenario: Issuer claim validation updated
- **WHEN** `JwtAntiTamperService` validates a JWT token
- **THEN** the system SHALL accept `iss` claim = "BasePlatform"
- **AND** the system SHALL reject tokens with `iss` claim = "UrbanManagement" (if old signing still exists)
- **AND** the system SHALL use BasePlatform public key for signature verification

### Requirement: BasePlatform API integration for JWT retrieval
`IJwtAntiTamperService` SHALL integrate with BasePlatform PublicApi to retrieve freshly signed JWT tokens after successful client JWT verification.

#### Scenario: Successful BasePlatform API call
- **WHEN** `VerifyAndCompareAsync` calls BasePlatform `/api/auth/license-file` with valid parameters
- **THEN** the request SHALL include `ProductCode = 5001` (Urban)
- **AND** the request SHALL include `ProId`, `MachineCode` (from `GovProject.MachineCode`), and `AuthEndDate` (from `GovProject.AuthEndDate`)
- **AND** the response SHALL contain a valid JWT signed by BasePlatform
- **AND** the system SHALL return this JWT in `JwtAntiTamperResult.ServerJwt`

#### Scenario: BasePlatform API timeout handling
- **WHEN** the call to BasePlatform API times out (超过 30 秒)
- **THEN** the system SHALL return `JwtAntiTamperResult.Fail` with timeout error message
- **AND** the system SHALL log the timeout event with ProId
- **AND** the system SHALL NOT retry automatically (client can retry on next attempt)

### Requirement: Feature flag for BasePlatform JWT delegation
The system SHALL provide a feature flag `UseBasePlatformJwtIssuer` to control whether JWT delegation is enabled, allowing gradual rollout and rollback.

#### Scenario: Feature flag enabled (default)
- **WHEN** `UseBasePlatformJwtIssuer = true` (default for new deployments)
- **THEN** `JwtAntiTamperService` SHALL call BasePlatform API for JWT retrieval
- **AND** the system SHALL reject tokens with `iss = "UrbanManagement"`

#### Scenario: Feature flag disabled (rollback)
- **WHEN** `UseBasePlatformJwtIssuer = false` (for rollback during testing)
- **THEN** `JwtAntiTamperService` MAY fall back to local `UrbanLicenseGenerator` (if still available)
- **AND** the system SHALL log a warning about using deprecated local signing
- **AND** this mode SHALL only be supported during transition period

### Requirement: Error handling and logging
The system SHALL provide comprehensive error handling and logging for JWT delegation failures.

#### Scenario: BasePlatform API returns error response
- **WHEN** BasePlatform API returns 4xx or 5xx error
- **THEN** the system SHALL extract error message from response body
- **AND** the system SHALL return `JwtAntiTamperResult.Fail` with safe error message
- **AND** the system SHALL log the full error details for debugging

#### Scenario: Network connectivity failure
- **WHEN** the system cannot reach BasePlatform API (network failure, DNS resolution failure, etc.)
- **THEN** the system SHALL return `JwtAntiTamperResult.Fail` with "无法连接到授权服务器，请检查网络连接"
- **AND** the system SHALL log the network error with exception details
- **AND** the system SHALL NOT expose internal exception details to client

#### Scenario: Invalid JWT format from BasePlatform
- **WHEN** BasePlatform API returns invalid or malformed JWT
- **THEN** the system SHALL log the error with JWT preview (first 10 chars)
- **AND** the system SHALL return `JwtAntiTamperResult.Fail` with "授权令牌格式无效"
- **AND** the system SHALL NOT propagate the invalid JWT to client
