## ADDED Requirements

### Requirement: PersistedJwtToken entity

`PersistedJwtToken` SHALL be an ABP aggregate root entity with the following properties: `ProId` (Guid, primary key), `JwtToken` (string, stores the raw JWT text), `ExpiresAt` (DateTime, extracted from JWT `exp` claim), and ABP standard audit properties (`CreationTime`, `ExtraProperties`). The entity SHALL be registered in `UrbanManagementDbContext` as a `DbSet<PersistedJwtToken>`.

#### Scenario: Entity creation with valid data

- **WHEN** a new `PersistedJwtToken` is created with ProId, JwtToken, and ExpiresAt
- **THEN** the entity SHALL store all three properties
- **AND** `CreationTime` SHALL be set to the current UTC time

### Requirement: PersistedJwtToken upsert on license generation

`UrbanLicenseGenerator.GenerateLicenseToken()` SHALL, after successfully generating a JWT token, persist it to the database. If a `PersistedJwtToken` record with the same `ProId` already exists, it SHALL be replaced (upsert). If no record exists, a new one SHALL be created.

#### Scenario: First license generation for a project

- **WHEN** `GenerateLicenseToken` is called for a ProId that has no existing `PersistedJwtToken` record
- **THEN** a new `PersistedJwtToken` record SHALL be inserted with the generated JWT text and ExpiresAt

#### Scenario: License re-generation for existing project

- **WHEN** `GenerateLicenseToken` is called for a ProId that already has a `PersistedJwtToken` record
- **THEN** the existing record SHALL be updated with the new JWT text and ExpiresAt

#### Scenario: License generation fails before persistence

- **WHEN** `GenerateLicenseToken` throws an exception during JWT generation
- **THEN** no database write SHALL occur

### Requirement: PersistedJwtToken repository

`IPersistedJwtTokenRepository` SHALL extend ABP's `IRepository<PersistedJwtToken>` and provide a `GetByProIdAsync(Guid proId)` method that returns the persisted token record for the given ProId, or `null` if none exists.

#### Scenario: Query existing token

- **WHEN** `GetByProIdAsync` is called with a ProId that has a persisted record
- **THEN** SHALL return the `PersistedJwtToken` entity

#### Scenario: Query non-existent token

- **WHEN** `GetByProIdAsync` is called with a ProId that has no persisted record
- **THEN** SHALL return `null`
