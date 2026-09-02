## MODIFIED Requirements

### Requirement: JWT anti-tamper verification service

`IJwtAntiTamperService` SHALL define a `VerifyAndCompareAsync(string jwtToken, Guid proId)` method that validates the submitted JWT token using RS256 signature verification, extracts the `proId` claim, queries the `GovProject` by that `proId`, and if the project exists and the JWT is valid, re-signs a fresh JWT from the `GovProject` data. The method SHALL return a `JwtAntiTamperResult`.

#### Scenario: Valid JWT with matching project

- **WHEN** `VerifyAndCompareAsync` is called with a JWT that has a valid RS256 signature, correct issuer (`UrbanManagement`) and audience (`MaterialClient.Urban`), and the `proId` claim matches an existing `GovProject` record
- **THEN** SHALL return `JwtAntiTamperResult` with `Passed = true`
- **AND** `ServerJwt` SHALL contain a freshly signed JWT from the `GovProject` data without an `fdBuildLicenseNo` claim
- **AND** `ProName`, `BuildLicenseNo`, `AuthEndTime` SHALL be populated from the `GovProject` fields

#### Scenario: Invalid RS256 signature

- **WHEN** `VerifyAndCompareAsync` is called with a JWT whose RS256 signature does not verify against the configured RSA public key
- **THEN** SHALL return `JwtAntiTamperResult` with `Passed = false` and `Reason` indicating signature verification failure

#### Scenario: No GovProject found for proId

- **WHEN** `VerifyAndCompareAsync` is called with a validly-signed JWT but no `GovProject` record exists for the `proId` extracted from the JWT claims
- **THEN** SHALL return `JwtAntiTamperResult` with `Passed = false` and `Reason` indicating the project was not found on the server

#### Scenario: Expired JWT submitted

- **WHEN** `VerifyAndCompareAsync` is called with a JWT whose `exp` claim is in the past (beyond clock skew tolerance)
- **THEN** SHALL return `JwtAntiTamperResult` with `Passed = false` and `Reason` indicating the token is expired

### Requirement: JwtAntiTamperResult DTO

`JwtAntiTamperResult` SHALL be a DTO with the following properties: `Passed` (bool), `Reason` (string?, null when passed), `ServerJwt` (string?, the freshly signed JWT when passed), `ProName` (string?), `BuildLicenseNo` (string?), `AuthEndTime` (DateTime?). The DTO MUST NOT include `FdBuildLicenseNo`. The `ServerJwt` and license fields SHALL only be populated when `Passed = true`.

#### Scenario: Success result excludes FdBuildLicenseNo
- **WHEN** anti-tamper verification passes and `JwtAntiTamperResult` is returned to the client
- **THEN** the result SHALL populate `ProName`, `BuildLicenseNo`, and `AuthEndTime` from `GovProject`
- **AND** MUST NOT include an `FdBuildLicenseNo` property or value
