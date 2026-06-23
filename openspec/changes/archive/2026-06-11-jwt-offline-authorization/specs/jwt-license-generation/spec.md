## ADDED Requirements

### Requirement: JWT license token generation

`UrbanLicenseGenerator.GenerateLicenseToken()` SHALL accept a request containing ProId (Guid), ProName (string), BuildLicenseNo (string), FdBuildLicenseNo (string), and ExpiresAt (DateTime). It SHALL create a JWT token signed with RS256 using the RSA private key from configuration (`Jwt:PrivateKey`). The token SHALL contain claims: `proId`, `proName`, `buildLicenseNo`, `fdBuildLicenseNo`, `exp` (Unix timestamp), `jti` (unique ID), `iss` ("UrbanManagement"), `aud` ("MaterialClient.Urban").

#### Scenario: Generate valid license token

- **WHEN** `GenerateLicenseToken` is called with a valid request containing a future `ExpiresAt`
- **THEN** SHALL return a JWT string with three parts (header.payload.signature)
- **AND** the `proId` claim SHALL equal the request's ProId as a string
- **AND** the `proName` claim SHALL equal the request's ProName
- **AND** the `buildLicenseNo` claim SHALL equal the request's BuildLicenseNo
- **AND** the `fdBuildLicenseNo` claim SHALL equal the request's FdBuildLicenseNo
- **AND** the `exp` claim SHALL be the Unix timestamp of `ExpiresAt`
- **AND** the `iss` claim SHALL be `"UrbanManagement"`
- **AND** the `aud` claim SHALL be `"MaterialClient.Urban"`
- **AND** the `jti` claim SHALL be a unique identifier

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
- **AND** SHALL generate a JWT token with claims populated from the project (ProId, ProName, BuildLicenseNo, FdBuildLicenseNo) and the provided `ExpiresAt`
- **AND** SHALL return a `FileContentResult` with the JWT as content, `application/octet-stream` content type, and `attachment; filename="license.urban"` disposition

#### Scenario: Project not found

- **WHEN** `GenerateAsync` is called with a `GovProjectId` that does not exist in the database
- **THEN** SHALL throw an `EntityNotFoundException` indicating the project was not found

#### Scenario: Project is soft-deleted

- **WHEN** `GenerateAsync` is called with a `GovProjectId` for a project where `IsDeleted = true`
- **THEN** SHALL treat the project as not found and throw an `EntityNotFoundException`

### Requirement: UrbanLicenseGenerator service registration

`UrbanLicenseGenerator` SHALL be registered via ABP implicit registration using `ITransientDependency` marker interface and `[AutoConstructor]` attribute. It SHALL implement `IUrbanLicenseGenerator`.

#### Scenario: DI resolution

- **WHEN** the ABP service provider resolves `IUrbanLicenseGenerator`
- **THEN** SHALL return a `UrbanLicenseGenerator` instance

### Requirement: License generation admin UI

UrbanManagement SHALL provide a UI for administrators to generate offline license files. The UI SHALL display a dropdown to select a GovProject, show the project's current details (ProName, BuildLicenseNo, AuthEndTime), allow setting a license expiration date, and provide a "Generate & Download" button that triggers the license generation API and downloads the `.urban` file.

#### Scenario: Generate license from UI

- **WHEN** an admin selects a GovProject from the dropdown, confirms or adjusts the expiration date, and clicks "Generate & Download"
- **THEN** SHALL call the license generation API with the selected project ID and expiration date
- **AND** SHALL trigger a browser file download of the resulting `license.urban` file

#### Scenario: No project selected

- **WHEN** the admin clicks "Generate & Download" without selecting a project
- **THEN** the generate button SHALL be disabled or the action SHALL be prevented

### Requirement: RSA private key configuration

`UrbanLicenseGenerator` SHALL load the RSA private key from application configuration at the key path `Jwt:PrivateKey` during construction. The key SHALL be in PEM format (`-----BEGIN RSA PRIVATE KEY-----`).

#### Scenario: Valid private key in configuration

- **WHEN** `UrbanLicenseGenerator` is constructed with a valid `Jwt:PrivateKey` PEM string in configuration
- **THEN** SHALL parse the private key successfully using `RSA.ImportFromPem()`
- **AND** SHALL use this key for signing all generated JWT tokens
