## ADDED Requirements

### Requirement: JWT license file validation

`JwtLicenseChecker.CheckLicenseAsync()` SHALL read the file at `licenseFilePath`, parse its content as a JWT token, validate the RS256 signature using the RSA public key loaded from configuration (`Jwt:PublicKey`), validate issuer (`UrbanManagement`) and audience (`MaterialClient.Urban`), validate token lifetime, and return a `LicenseCheckResult`.

#### Scenario: Valid JWT license file

- **WHEN** `CheckLicenseAsync` is called with a path to a `.urban` file containing a valid RS256-signed JWT with unexpired claims
- **THEN** SHALL return `LicenseCheckResult` with `IsSuccess = true`
- **AND** `ProId` SHALL be parsed from the `proId` claim as a `Guid`
- **AND** `ProName` SHALL be extracted from the `proName` claim
- **AND** `BuildLicenseNo` SHALL be extracted from the `buildLicenseNo` claim
- **AND** `FdBuildLicenseNo` SHALL be extracted from the `fdBuildLicenseNo` claim
- **AND** `AuthEndTime` SHALL be converted from the `exp` claim (Unix timestamp) to `DateTime`

#### Scenario: License file does not exist

- **WHEN** `CheckLicenseAsync` is called with a path to a file that does not exist
- **THEN** SHALL return `LicenseCheckResult` with `IsSuccess = false`
- **AND** `Message` SHALL indicate the license file was not found

#### Scenario: Invalid JWT signature

- **WHEN** `CheckLicenseAsync` is called with a file whose JWT signature does not match the configured RSA public key
- **THEN** SHALL return `LicenseCheckResult` with `IsSuccess = false`
- **AND** `Message` SHALL indicate signature validation failure

#### Scenario: Expired JWT token

- **WHEN** `CheckLicenseAsync` is called with a validly-signed JWT whose `exp` claim is in the past (beyond clock skew tolerance)
- **THEN** SHALL return `LicenseCheckResult` with `IsSuccess = false`
- **AND** `Message` SHALL indicate the license has expired and include the expiration date

#### Scenario: Tampered JWT claims

- **WHEN** `CheckLicenseAsync` is called with a JWT whose payload has been modified after signing
- **THEN** SHALL return `LicenseCheckResult` with `IsSuccess = false`
- **AND** `Message` SHALL indicate validation failure

#### Scenario: Malformed or empty file

- **WHEN** `CheckLicenseAsync` is called with a file that is not a valid JWT format
- **THEN** SHALL return `LicenseCheckResult` with `IsSuccess = false`
- **AND** `Message` SHALL indicate the file content is not a valid JWT token

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
