## MODIFIED Requirements

### Requirement: JWT license file validation

`JwtLicenseChecker.CheckLicenseAsync()` SHALL read the file at `licenseFilePath`, parse its content as a JWT token, validate the RS256 signature using the RSA public key loaded from configuration (`Jwt:PublicKey`), validate issuer (`UrbanManagement`) and audience (`MaterialClient.Urban`), validate token lifetime, and return a `LicenseCheckResult`.

#### Scenario: Valid JWT license file

- **WHEN** `CheckLicenseAsync` is called with a path to a `.urban` file containing a valid RS256-signed JWT with unexpired claims
- **THEN** SHALL return `LicenseCheckResult` with `IsSuccess = true`
- **AND** `ProId` SHALL be parsed from the `proId` claim as a `Guid`
- **AND** `ProName` SHALL be extracted from the `proName` claim
- **AND** `BuildLicenseNo` SHALL be extracted from the `buildLicenseNo` claim
- **AND** `AuthEndTime` SHALL be converted from the `exp` claim (Unix timestamp) to `DateTime`
- **AND** a missing or empty `fdBuildLicenseNo` claim MUST NOT cause validation failure
