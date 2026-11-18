## MODIFIED Requirements

### Requirement: Host applies kernel migrations then product migrations

Urban and Recycle hosts SHALL apply pending kernel migrations before pending product migrations at startup. The Standard host SHALL apply kernel migrations, then `StandardDbContext` migrations. The SolidWaste host SHALL apply kernel migrations, then `SolidWasteDbContext` migrations, then SolidWaste extension backfill. The Standard host MUST NOT apply `SolidWasteDbContext`, `UrbanDbContext`, or `RecycleDbContext` migrations. The SolidWaste host MUST NOT apply `StandardDbContext`, `UrbanDbContext`, or `RecycleDbContext` migrations. Urban and Recycle hosts MUST NOT apply `StandardDbContext` or `SolidWasteDbContext` migrations.

#### Scenario: Urban startup migrate order

- **WHEN** Urban `OnApplicationInitializationAsync` runs database migration
- **THEN** it SHALL migrate `MaterialClientDbContext` first
- **AND** SHALL then migrate `UrbanDbContext`
- **AND** MUST NOT migrate `StandardDbContext` or `SolidWasteDbContext`

#### Scenario: Standard host does not migrate Urban schema

- **WHEN** the standard `MaterialClient` host applies EF migrations
- **THEN** it MUST NOT apply `UrbanDbContext` or `RecycleDbContext` migrations
- **AND** MUST NOT apply `SolidWasteDbContext` migrations

#### Scenario: Standard host migrates kernel then Standard

- **WHEN** the standard `MaterialClient` host applies startup migrations
- **THEN** it SHALL migrate `MaterialClientDbContext` first
- **AND** SHALL then migrate `StandardDbContext`

#### Scenario: SolidWaste host migrates kernel then SolidWaste

- **WHEN** the `MaterialClient.SolidWaste` host applies startup migrations
- **THEN** it SHALL migrate `MaterialClientDbContext` first
- **AND** SHALL then migrate `SolidWasteDbContext`
- **AND** SHALL then backfill missing SolidWaste extension rows
