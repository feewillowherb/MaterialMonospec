# JWT Offline License Specification

## Purpose

定义基于 JWT RS256 签名的离线授权验证能力，包括 `.urban` 许可证文件解析、签名验证、声明提取及服务注册。
## Requirements
### Requirement: JWT license file validation

`StaticLicenseChecker`（实现 `IStaticLicenseChecker`，现网类名可能为 `JwtLicenseChecker` 或 `StaticLicenseChecker`）SHALL 读取 JWT 文本（自文件或 token 字符串），使用配置 `Jwt:PublicKey`（BasePlatform RSA 公钥，PEM）验证 RS256 签名，验证 issuer **`BasePlatform`**（唯一接受）与 audience **`MaterialClient.Urban`**，验证 token 生命周期，校验 **`machineCode`** claim 与本机机器码一致，并返回 `LicenseCheckResult`。

#### Scenario: Valid JWT license file

- **WHEN** `CheckLicenseAsync` 或 `CheckLicenseFromTokenAsync` 收到有效 RS256 JWT，`iss=BasePlatform`，`aud=MaterialClient.Urban`，未过期，且 `machineCode` 与本机一致
- **THEN** SHALL 返回 `LicenseCheckResult` 且 `IsSuccess = true`
- **AND** `ProId` SHALL 从 `proId` claim 解析为 `Guid`
- **AND** `ProName` SHALL 从 `proName` claim 提取
- **AND** `AccessCode` SHALL 从 **`accessCode`** claim 提取
- **AND** `AuthEndTime` SHALL 由 `exp` claim 转换
- **AND** MUST NOT 从 `buildLicenseNo` 或 `fdBuildLicenseNo` claim 提取接入码

#### Scenario: License file does not exist

- **WHEN** `CheckLicenseAsync` is called with a path to a file that does not exist
- **THEN** SHALL return `LicenseCheckResult` with `IsSuccess = false`
- **AND** `Message` SHALL indicate the license file was not found

#### Scenario: Invalid JWT signature

- **WHEN** JWT signature does not match the configured RSA public key
- **THEN** SHALL return `LicenseCheckResult` with `IsSuccess = false`
- **AND** `Message` SHALL indicate signature validation failure

#### Scenario: Expired JWT token

- **WHEN** JWT is validly signed but `exp` is in the past (beyond clock skew tolerance)
- **THEN** SHALL return `LicenseCheckResult` with `IsSuccess = false`
- **AND** `Message` SHALL indicate the license has expired and include the expiration date

#### Scenario: Tampered JWT claims

- **WHEN** JWT payload has been modified after signing
- **THEN** SHALL return `LicenseCheckResult` with `IsSuccess = false`
- **AND** `Message` SHALL indicate validation failure

#### Scenario: Malformed or empty file

- **WHEN** file content is not valid JWT format
- **THEN** SHALL return `LicenseCheckResult` with `IsSuccess = false`
- **AND** `Message` SHALL indicate the file content is not a valid JWT token

#### Scenario: Reject non-BasePlatform issuer

- **WHEN** JWT `iss` claim is `UrbanManagement` or any value other than `BasePlatform`
- **THEN** SHALL return `LicenseCheckResult` with `IsSuccess = false`
- **AND** MUST NOT 提供 `Jwt:LegacyIssuers` 或兼容分支接受旧 issuer

#### Scenario: Reject JWT without accessCode claim

- **WHEN** JWT 仅含 `buildLicenseNo` 或 `fdBuildLicenseNo` claim 而无 `accessCode`
- **THEN** SHALL return `LicenseCheckResult` with `IsSuccess = false`
- **AND** `Message` SHALL indicate missing or invalid access code claim

#### Scenario: Machine code mismatch

- **WHEN** JWT `machineCode` claim 存在且与本机机器码不一致
- **THEN** SHALL return `LicenseCheckResult` with `IsSuccess = false`
- **AND** `Message` SHALL indicate machine code mismatch

### Requirement: RSA public key configuration

`JwtLicenseChecker` SHALL load the RSA public key from application configuration at the key path `Jwt:PublicKey` during construction. The key SHALL be in PEM format (`-----BEGIN PUBLIC KEY-----`). If the key is missing or invalid, the constructor SHALL log a warning but not throw — subsequent `CheckLicenseAsync` calls SHALL fail with a descriptive message.

#### Scenario: Valid public key in configuration

- **WHEN** `JwtLicenseChecker` is constructed with a valid `Jwt:PublicKey` PEM string in configuration
- **THEN** SHALL parse the public key successfully using `RSA.ImportFromPem()`
- **AND** subsequent `CheckLicenseAsync` calls SHALL use this key for signature verification

#### Scenario: Missing public key configuration

- **WHEN** `JwtLicenseChecker` is constructed with no `Jwt:PublicKey` value in configuration
- **THEN** SHALL log a warning that the public key is not configured
- **AND** subsequent `CheckLicenseAsync` calls SHALL return `LicenseCheckResult.Fail` with a message indicating the public key is not configured

#### Scenario: Invalid PEM format

- **WHEN** `JwtLicenseChecker` is constructed with a `Jwt:PublicKey` value that is not valid PEM format
- **THEN** SHALL log an error indicating the public key format is invalid
- **AND** subsequent `CheckLicenseAsync` calls SHALL return `LicenseCheckResult.Fail` with a message indicating the key could not be parsed

### Requirement: JwtLicenseChecker service registration

`JwtLicenseChecker` SHALL be registered as a singleton via ABP implicit registration using `ISingletonDependency` marker interface and `[AutoConstructor]` attribute. It SHALL implement `IStaticLicenseChecker`.

#### Scenario: DI resolution

- **WHEN** the ABP service provider resolves `IStaticLicenseChecker`
- **THEN** SHALL return the `JwtLicenseChecker` instance as a singleton

### Requirement: License file path default

`SystemSettings.LicenseFilePath` SHALL default to `"license.urban"` (changed from previous `"RSA.xml"`).

#### Scenario: Default license file path

- **WHEN** a new `SystemSettings` instance is created without explicitly setting `LicenseFilePath`
- **THEN** `LicenseFilePath` SHALL be `"license.urban"`

