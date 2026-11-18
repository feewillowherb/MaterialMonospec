## MODIFIED Requirements

### Requirement: Host applies kernel migrations then product migrations

Urban and Recycle hosts SHALL apply pending kernel migrations before pending product migrations at startup. The standard host SHALL apply kernel migrations, then `StandardDbContext` migrations, then `SolidWasteDbContext` migrations. The standard host MUST NOT apply `UrbanDbContext` or `RecycleDbContext` migrations. Urban and Recycle hosts MUST NOT apply `StandardDbContext` or `SolidWasteDbContext` migrations.

#### Scenario: Urban startup migrate order

- **WHEN** Urban `OnApplicationInitializationAsync` runs database migration
- **THEN** it SHALL migrate `MaterialClientDbContext` first
- **AND** SHALL then migrate `UrbanDbContext`
- **AND** MUST NOT migrate `StandardDbContext` or `SolidWasteDbContext`

#### Scenario: Standard host does not migrate Urban schema

- **WHEN** the standard `MaterialClient` host applies EF migrations
- **THEN** it MUST NOT apply `UrbanDbContext` or `RecycleDbContext` migrations

#### Scenario: Standard host migrates kernel then both product contexts

- **WHEN** the standard `MaterialClient` host applies startup migrations
- **THEN** it SHALL migrate `MaterialClientDbContext` first
- **AND** SHALL then migrate `StandardDbContext`
- **AND** SHALL then migrate `SolidWasteDbContext`
