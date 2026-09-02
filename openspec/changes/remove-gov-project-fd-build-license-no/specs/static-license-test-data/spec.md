## MODIFIED Requirements

### Requirement: StaticLicenseChecker reads and decrypts RSA.xml authorization data

`StaticLicenseChecker.CheckLicenseAsync()` SHALL read the RSA.xml file at the given path, use `RsaLicenseDecryptor.ReadAndDecrypt()` to decrypt the authorization data, validate expiration, and return a `LicenseCheckResult` reflecting the authorization status. The check SHALL return fail if the file is missing, decryption fails, or authorization has expired.

#### Scenario: Valid RSA.xml with active authorization

- **WHEN** `StaticLicenseChecker.CheckLicenseAsync()` is called with a path to a valid RSA.xml where the decrypted `authEndTime` is in the future
- **THEN** SHALL return `LicenseCheckResult.IsSuccess = true`
- **AND** SHALL include `AuthEndTime` set to the decrypted expiration date
- **AND** SHALL include a message containing the expiration date and remaining days
- **AND** SHALL include `BuildLicenseNo` set to the decrypted xmlString value
- **AND** SHALL include `ProId` set to `Guid.Parse` of the decrypted proId value
- **AND** `ProName` SHALL be null (not present in RSA.xml)
- **AND** MUST NOT populate `FdBuildLicenseNo`

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

`LicenseCheckResult` SHALL include optional properties for ProId (Guid), ProName (string), and BuildLicenseNo (string) to convey parsed license information from the checker to the startup flow. `LicenseCheckResult` MUST NOT include `FdBuildLicenseNo`.

#### Scenario: Success result with data

- **WHEN** a `LicenseCheckResult` is created via `LicenseCheckResult.Success()`
- **THEN** SHALL allow setting ProId, ProName, BuildLicenseNo properties
- **AND** all properties SHALL be accessible to callers
- **AND** MUST NOT expose `FdBuildLicenseNo`

#### Scenario: Fail result without data

- **WHEN** a `LicenseCheckResult` is created via `LicenseCheckResult.Fail()`
- **THEN** ProId, ProName, BuildLicenseNo SHALL be null/default
- **AND** `IsSuccess` SHALL be false

### Requirement: LicenseInfo entity extended with project fields

`LicenseInfo` entity SHALL include `ProName` (string?) and `BuildLicenseNo` (string?) fields to persist project association information locally. `LicenseInfo` MUST NOT include `FdBuildLicenseNo`.

#### Scenario: New LicenseInfo with project fields

- **WHEN** a new `LicenseInfo` is created with ProName, BuildLicenseNo
- **THEN** those fields SHALL be persisted to the database
- **AND** MUST NOT persist `FdBuildLicenseNo`

#### Scenario: Existing LicenseInfo records

- **WHEN** existing `LicenseInfo` records exist in the database
- **THEN** a migration MAY drop the obsolete `FdBuildLicenseNo` column
- **AND** remaining fields SHALL be preserved

### Requirement: Startup flow writes static license data to LicenseInfo

`MaterialClientUrbanModule.OnApplicationInitializationAsync` SHALL, after successful static license check, write the license data (ProId, ProName, BuildLicenseNo) from `LicenseCheckResult` into the `LicenseInfo` entity, persisting it to the local database.

#### Scenario: First startup with no existing LicenseInfo

- **WHEN** application starts and static license check succeeds and no LicenseInfo record exists
- **THEN** SHALL create a new LicenseInfo with ProId, ProName, BuildLicenseNo from the check result
- **AND** SHALL persist it to the database

#### Scenario: Startup with existing LicenseInfo

- **WHEN** application starts and static license check succeeds and a LicenseInfo record already exists
- **THEN** SHALL update the existing LicenseInfo with ProName, BuildLicenseNo from the check result
- **AND** SHALL preserve the existing ProId if it matches, or update if changed

#### Scenario: Static license check fails

- **WHEN** application starts and static license check fails
- **THEN** SHALL NOT modify any existing LicenseInfo record
- **AND** SHALL log a warning
- **AND** application SHALL continue startup (non-blocking)
