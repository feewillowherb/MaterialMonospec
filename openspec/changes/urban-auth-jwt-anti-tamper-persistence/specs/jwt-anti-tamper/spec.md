## ADDED Requirements

### Requirement: JWT anti-tamper verification service

`IJwtAntiTamperService` SHALL define a `VerifyAndCompareAsync(string jwtToken, Guid proId)` method that validates the submitted JWT token against the server-persisted record. The method SHALL return a `JwtAntiTamperResult`.

#### Scenario: Valid JWT matching persisted token

- **WHEN** `VerifyAndCompareAsync` is called with a JWT that has a valid RS256 signature, correct issuer (`UrbanManagement`) and audience (`MaterialClient.Urban`), and whose raw text exactly matches the persisted JWT for the given ProId
- **THEN** SHALL return `JwtAntiTamperResult` with `Passed = true`
- **AND** `ProName`, `BuildLicenseNo`, `FdBuildLicenseNo`, `AuthEndTime` SHALL be populated from the JWT claims

#### Scenario: Invalid RS256 signature

- **WHEN** `VerifyAndCompareAsync` is called with a JWT whose RS256 signature does not verify against the configured RSA public key
- **THEN** SHALL return `JwtAntiTamperResult` with `Passed = false` and `Reason` indicating signature verification failure

#### Scenario: No persisted token found for ProId

- **WHEN** `VerifyAndCompareAsync` is called with a validly-signed JWT but no `PersistedJwtToken` record exists for the given ProId
- **THEN** SHALL return `JwtAntiTamperResult` with `Passed = false` and `Reason` indicating no server record exists

#### Scenario: JWT text mismatch

- **WHEN** `VerifyAndCompareAsync` is called with a validly-signed JWT whose raw text does not exactly match the persisted JWT for the given ProId
- **THEN** SHALL return `JwtAntiTamperResult` with `Passed = false` and `Reason` indicating token mismatch (tampering detected)

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

`JwtAntiTamperResult` SHALL be a DTO with the following properties: `Passed` (bool), `Reason` (string?, null when passed), `ProName` (string?), `BuildLicenseNo` (string?), `FdBuildLicenseNo` (string?), `AuthEndTime` (DateTime?). The license fields SHALL only be populated when `Passed = true`.
