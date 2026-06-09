# Static License Test Data Specification

## Purpose

定义静态授权检查器（StaticLicenseChecker）返回硬编码测试数据的能力，以及 LicenseCheckResult 和 LicenseInfo 实体扩展以携带项目关联信息（ProId、ProName、BuildLicenseNo、FdBuildLicenseNo），用于开发和测试环境。

## Requirements

### Requirement: StaticLicenseChecker reads and decrypts RSA.xml authorization data

`StaticLicenseChecker.CheckLicenseAsync()` SHALL read the RSA.xml file at the given path, use `RsaLicenseDecryptor.ReadAndDecrypt()` to decrypt the authorization data, validate expiration, and return a `LicenseCheckResult` reflecting the authorization status. The check SHALL return fail if the file is missing, decryption fails, or authorization has expired.

#### Scenario: Valid RSA.xml with active authorization

- **WHEN** `StaticLicenseChecker.CheckLicenseAsync()` is called with a path to a valid RSA.xml where the decrypted `authEndTime` is in the future
- **THEN** SHALL return `LicenseCheckResult.IsSuccess = true`
- **AND** SHALL include `AuthEndTime` set to the decrypted expiration date
- **AND** SHALL include a message containing the expiration date and remaining days
- **AND** SHALL include `BuildLicenseNo` set to the decrypted xmlString value
- **AND** SHALL include `ProId` set to `Guid.Parse` of the decrypted proId value
- **AND** `ProName`, `FdBuildLicenseNo` SHALL be null (not present in RSA.xml)

#### Scenario: Valid RSA.xml with expired authorization

- **WHEN** `StaticLicenseChecker.CheckLicenseAsync()` is called with a path to a valid RSA.xml where the decrypted `authEndTime` is in the past
- **THEN** SHALL return `LicenseCheckResult.IsSuccess = false`
- **AND** SHALL include a message indicating the authorization has expired with the expiration date and days overdue

#### Scenario: RSA.xml file does not exist

- **WHEN** `StaticLicenseChecker.CheckLicenseAsync()` is called with a path to a non-existent file
- **THEN** SHALL return `LicenseCheckResult.Fail()` with a message indicating the file was not found
- **AND** SHALL log a warning

#### Scenario: RSA.xml contains malformed XML

- **WHEN** `StaticLicenseChecker.CheckLicenseAsync()` is called with a path to a file that is not valid XML
- **THEN** SHALL return `LicenseCheckResult.Fail()` with a message about the parse error
- **AND** SHALL log an error

#### Scenario: RSA.xml decryption fails

- **WHEN** `StaticLicenseChecker.CheckLicenseAsync()` is called with an RSA.xml that contains invalid encrypted data or wrong private key
- **THEN** SHALL return `LicenseCheckResult.Fail()` with a message about the decryption error
- **AND** SHALL log an error

### Requirement: LicenseCheckResult carries license data

`LicenseCheckResult` SHALL include optional properties for ProId (Guid), ProName (string), BuildLicenseNo (string), and FdBuildLicenseNo (string) to convey parsed license information from the checker to the startup flow.

#### Scenario: Success result with data

- **WHEN** a `LicenseCheckResult` is created via `LicenseCheckResult.Success()`
- **THEN** SHALL allow setting ProId, ProName, BuildLicenseNo, FdBuildLicenseNo properties
- **AND** all properties SHALL be accessible to callers

#### Scenario: Fail result without data

- **WHEN** a `LicenseCheckResult` is created via `LicenseCheckResult.Fail()`
- **THEN** ProId, ProName, BuildLicenseNo, FdBuildLicenseNo SHALL be null/default
- **AND** `IsSuccess` SHALL be false

### Requirement: LicenseInfo entity extended with project fields

`LicenseInfo` entity SHALL include `ProName` (string?), `BuildLicenseNo` (string?), and `FdBuildLicenseNo` (string?) fields to persist the full project association information locally.

#### Scenario: New LicenseInfo with project fields

- **WHEN** a new `LicenseInfo` is created with ProName, BuildLicenseNo, FdBuildLicenseNo
- **THEN** all fields SHALL be persisted to the database
- **AND** an EF Core migration SHALL exist to add these columns to the LicenseInfo table

#### Scenario: Existing LicenseInfo records

- **WHEN** existing `LicenseInfo` records exist in the database
- **THEN** the migration SHALL add nullable columns without data loss
- **AND** existing records SHALL have null values for the new fields

### Requirement: Startup flow writes static license data to LicenseInfo

`MaterialClientUrbanModule.OnApplicationInitializationAsync` SHALL, after successful static license check, write the license data (ProId, ProName, BuildLicenseNo, FdBuildLicenseNo) from `LicenseCheckResult` into the `LicenseInfo` entity, persisting it to the local database.

#### Scenario: First startup with no existing LicenseInfo

- **WHEN** application starts and static license check succeeds and no LicenseInfo record exists
- **THEN** SHALL create a new LicenseInfo with ProId, ProName, BuildLicenseNo, FdBuildLicenseNo from the check result
- **AND** SHALL persist it to the database

#### Scenario: Startup with existing LicenseInfo

- **WHEN** application starts and static license check succeeds and a LicenseInfo record already exists
- **THEN** SHALL update the existing LicenseInfo with ProName, BuildLicenseNo, FdBuildLicenseNo from the check result
- **AND** SHALL preserve the existing ProId if it matches, or update if changed

#### Scenario: Static license check fails

- **WHEN** application starts and static license check fails
- **THEN** SHALL NOT modify any existing LicenseInfo record
- **AND** SHALL log a warning
- **AND** application SHALL continue startup (non-blocking)

### Requirement: IStaticLicenseChecker interface unchanged

`IStaticLicenseChecker` interface signature SHALL remain `Task<LicenseCheckResult> CheckLicenseAsync(string licenseFilePath)`. The data flows through the `LicenseCheckResult` return type, not through interface changes.

#### Scenario: Interface compatibility

- **WHEN** any code depends on `IStaticLicenseChecker`
- **THEN** the method signature SHALL remain unchanged
- **AND** data SHALL be carried in the `LicenseCheckResult` object
