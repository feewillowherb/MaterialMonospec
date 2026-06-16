## ADDED Requirements

### Requirement: JWT anti-tamper verification service

`IJwtAntiTamperService` SHALL define a `VerifyAndCompareAsync(string jwtToken, Guid proId)` method that validates the submitted JWT token using RS256 signature verification, extracts the `proId` claim, queries the `GovProject` by that `proId`, and if the project exists and the JWT is valid, re-signs a fresh JWT from the `GovProject` data. The method SHALL return a `JwtAntiTamperResult`.

#### Scenario: Valid JWT with matching project

- **WHEN** `VerifyAndCompareAsync` is called with a JWT that has a valid RS256 signature, correct issuer (`UrbanManagement`) and audience (`MaterialClient.Urban`), and the `proId` claim matches an existing `GovProject` record
- **THEN** SHALL return `JwtAntiTamperResult` with `Passed = true`
- **AND** `ServerJwt` SHALL contain a freshly signed JWT from the `GovProject` data
- **AND** `ProName`, `BuildLicenseNo`, `FdBuildLicenseNo`, `AuthEndTime` SHALL be populated from the `GovProject` fields

#### Scenario: Invalid RS256 signature

- **WHEN** `VerifyAndCompareAsync` is called with a JWT whose RS256 signature does not verify against the configured RSA public key
- **THEN** SHALL return `JwtAntiTamperResult` with `Passed = false` and `Reason` indicating signature verification failure

#### Scenario: No GovProject found for proId

- **WHEN** `VerifyAndCompareAsync` is called with a validly-signed JWT but no `GovProject` record exists for the `proId` extracted from the JWT claims
- **THEN** SHALL return `JwtAntiTamperResult` with `Passed = false` and `Reason` indicating the project was not found on the server

#### Scenario: Expired JWT submitted

- **WHEN** `VerifyAndCompareAsync` is called with a JWT whose `exp` claim is in the past (beyond clock skew tolerance)
- **THEN** SHALL return `JwtAntiTamperResult` with `Passed = false` and `Reason` indicating the token is expired

### Requirement: SignalR Hub JWT verification endpoint

`DeviceStatusHub` SHALL expose a `VerifyJwtAsync(string jwtToken, string proId)` hub method that calls `IJwtAntiTamperService.VerifyAndCompareAsync` and returns the `JwtAntiTamperResult`. The `proId` parameter SHALL be parsed as a Guid; if parsing fails, the method SHALL return a fail result.

#### Scenario: Valid request via SignalR

- **WHEN** a connected client invokes `VerifyJwtAsync` with a JWT string and a valid GUID string as proId
- **THEN** SHALL return the `JwtAntiTamperResult` from the anti-tamper service

#### Scenario: Invalid proId format

- **WHEN** a client invokes `VerifyJwtAsync` with a proId string that is not a valid GUID
- **THEN** SHALL return `JwtAntiTamperResult` with `Passed = false` and `Reason` indicating invalid ProId format

### Requirement: JwtAntiTamperResult DTO

`JwtAntiTamperResult` SHALL be a DTO with the following properties: `Passed` (bool), `Reason` (string?, null when passed), `ServerJwt` (string?, the freshly signed JWT when passed), `ProName` (string?), `BuildLicenseNo` (string?), `FdBuildLicenseNo` (string?), `AuthEndTime` (DateTime?). The `ServerJwt` and license fields SHALL only be populated when `Passed = true`.
