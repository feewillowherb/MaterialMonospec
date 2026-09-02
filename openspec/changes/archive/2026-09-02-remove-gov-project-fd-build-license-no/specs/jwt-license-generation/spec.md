## MODIFIED Requirements

### Requirement: JWT license token generation

`UrbanLicenseGenerator.GenerateLicenseToken()` SHALL accept a request containing ProId (Guid), ProName (string), BuildLicenseNo (string), and ExpiresAt (DateTime). It SHALL create a JWT token signed with RS256 using the RSA private key from configuration (`Jwt:PrivateKey`). The token SHALL contain claims: `proId`, `proName`, `buildLicenseNo`, `exp` (Unix timestamp), `jti` (unique ID), `iss` ("UrbanManagement"), `aud` ("MaterialClient.Urban"). The token MUST NOT contain an `fdBuildLicenseNo` claim.

#### Scenario: Generate valid license token

- **WHEN** `GenerateLicenseToken` is called with a valid request containing a future `ExpiresAt`
- **THEN** SHALL return a JWT string with three parts (header.payload.signature)
- **AND** the `proId` claim SHALL equal the request's ProId as a string
- **AND** the `proName` claim SHALL equal the request's ProName
- **AND** the `buildLicenseNo` claim SHALL equal the request's BuildLicenseNo
- **AND** the `exp` claim SHALL be the Unix timestamp of `ExpiresAt`
- **AND** the `iss` claim SHALL be `"UrbanManagement"`
- **AND** the `aud` claim SHALL be `"MaterialClient.Urban"`
- **AND** the `jti` claim SHALL be a unique identifier
- **AND** MUST NOT include an `fdBuildLicenseNo` claim

#### Scenario: Missing private key configuration

- **WHEN** `UrbanLicenseGenerator` is constructed with no `Jwt:PrivateKey` value in configuration
- **THEN** SHALL throw an `InvalidOperationException` indicating the private key is not configured

#### Scenario: Invalid PEM format for private key

- **WHEN** `UrbanLicenseGenerator` is constructed with a `Jwt:PrivateKey` value that is not valid PEM format
- **THEN** SHALL throw an `InvalidOperationException` indicating the private key format is invalid

### Requirement: License generation API endpoint

`GovProjectLicenseAppService` SHALL expose a `GenerateAsync` method that accepts a `GovProjectId` (Guid) and `ExpiresAt` (DateTime), loads the corresponding `GovProject` entity, calls `IUrbanLicenseGenerator.GenerateLicenseToken()`, and returns the JWT string as a file download with content type `application/octet-stream` and filename `license.urban`.

#### Scenario: Generate license for existing project

- **WHEN** `GenerateAsync` is called with a valid `GovProjectId` and a future `ExpiresAt`
- **THEN** SHALL load the `GovProject` from the repository
- **AND** SHALL generate a JWT token with claims populated from the project (ProId, ProName, BuildLicenseNo) and the provided `ExpiresAt`
- **AND** MUST NOT read or emit `FdBuildLicenseNo`
- **AND** SHALL return a `FileContentResult` with the JWT as content, `application/octet-stream` content type, and `attachment; filename="license.urban"` disposition

#### Scenario: Project not found

- **WHEN** `GenerateAsync` is called with a `GovProjectId` that does not exist in the database
- **THEN** SHALL throw an `EntityNotFoundException` indicating the project was not found

#### Scenario: Project is soft-deleted

- **WHEN** `GenerateAsync` is called with a `GovProjectId` for a project where `IsDeleted = true`
- **THEN** SHALL treat the project as not found and throw an `EntityNotFoundException`
