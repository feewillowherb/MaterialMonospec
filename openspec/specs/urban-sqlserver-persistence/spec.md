# urban-sqlserver-persistence Specification

## Purpose
TBD - created by archiving change update-urban-mssql-provider. Update Purpose after archive.
## Requirements
### Requirement: Core module configures ABP EF Core with SQL Server

`UrbanManagementCoreModule` SHALL depend on `AbpEntityFrameworkCoreModule` and `AbpEntityFrameworkCoreSqlServerModule`, register `UrbanManagementDbContext` with `AddDefaultRepositories(true)`, and configure `AbpDbContextOptions` with `UseSqlServer()` using the `Default` connection string. `UrbanManagement.Core` MUST NOT reference any SQLite EF Core package.

#### Scenario: DbContext is registered with ABP on SQL Server

- **WHEN** the application starts with a reachable SQL Server `Default` connection string
- **THEN** `UrbanManagementDbContext` SHALL be available through ABP's repository pattern
- **AND** the active EF Core provider SHALL be `Microsoft.EntityFrameworkCore.SqlServer`

#### Scenario: Production connection string comes from environment

- **WHEN** the environment variable `ConnectionStrings__Default` is set
- **THEN** the application SHALL use that value instead of the development connection string in `appsettings.json`
- **AND** `appsettings.json` committed to the repository MUST NOT contain a database password

### Requirement: Single SQL Server migration baseline

The `UrbanManagementDbContext` migrations SHALL consist of a collation-only migration (`SetDatabaseCollation`), a single SQL Server schema baseline (`InitialSqlServer`), and only SQL Server migrations after it. SQLite-dialect migrations MUST NOT be compiled into `UrbanManagement.Core`. Applying all migrations to an empty SQL Server database SHALL create every table and index defined by the model.

#### Scenario: Empty database migrates to current model

- **WHEN** `Database.MigrateAsync()` runs against an empty SQL Server database
- **THEN** all tables mapped by `UrbanManagementDbContext` SHALL exist with their configured indexes
- **AND** `dotnet ef migrations has-pending-model-changes` (or equivalent) SHALL report no pending model changes

### Requirement: Database collation is Chinese_PRC_CI_AS

The model SHALL declare database collation `Chinese_PRC_CI_AS`, and the migrations SHALL apply it both when the database is created by EF and when an empty database was pre-created with the server default collation.

#### Scenario: Collation applied on a server with a different default

- **WHEN** the migrations run on a SQL Server instance whose default collation is `SQL_Latin1_General_CP1_CI_AS` and the database does not exist yet
- **THEN** the resulting database collation SHALL be `Chinese_PRC_CI_AS`

#### Scenario: Collation applied to a pre-created empty database

- **WHEN** an empty database was created with the server default collation and the migrations then run against it
- **THEN** the database collation SHALL be `Chinese_PRC_CI_AS` after migration

### Requirement: Weight decimals have explicit precision

`UrbanWeighingRecord.TotalWeight` and `GovSyncData.GoodsWeight` SHALL be mapped as `decimal(18,4)`. Values with up to 4 fractional digits MUST round-trip without change.

#### Scenario: Weight with three decimals persists unchanged

- **WHEN** a weighing record with `TotalWeight = 12.345` is saved and read back
- **THEN** the stored and returned value SHALL be `12.345`

#### Scenario: Column type in schema

- **WHEN** the `UrbanWeighingRecords` and `GovSyncData` tables are inspected
- **THEN** `TotalWeight` and `GoodsWeight` SHALL have SQL type `decimal(18,4)`

