## MODIFIED Requirements

### Requirement: MaterialClientUrbanModule AbpModule definition

The system SHALL define a `MaterialClientUrbanModule` class that extends `AbpModule` with the following dependencies: `MaterialClientCommonModule`, kernel EF module (`MaterialClientEntityFrameworkCoreModule` or equivalent if kernel EF remains in Common temporarily), `MaterialClientCommonUrbanModule` (from `MaterialClient.Common.Urban`), `AbpAutofacModule`. This module MUST NOT depend on `MaterialClientModule` (the main app module).

#### Scenario: Module dependency chain
- **WHEN** the ABP application initializes with `MaterialClientUrbanModule`
- **THEN** the module SHALL depend on `MaterialClientCommonModule` (kernel entities and kernel Service APIs)
- **AND** SHALL depend on the kernel EF module that provides `MaterialClientDbContext` without Urban/Recycle entity mappings
- **AND** SHALL depend on `MaterialClientCommonUrbanModule` (Urban entities, `UrbanDbContext`, Urban Service APIs)
- **AND** SHALL depend on `AbpAutofacModule` (provides Autofac DI container)
- **AND** MUST NOT depend on `MaterialClientModule`

#### Scenario: Service configuration
- **WHEN** `ConfigureServices` is called during ABP initialization
- **THEN** the module SHALL configure Serilog logging with daily rotation (matching MaterialClient's pattern)
- **AND** SHALL NOT register Refit API clients (Urban has no platform API)
- **AND** SHALL NOT register `MaterialClient.Backgrounds.PollingBackgroundService` or `MinimalWebHostService`
- **AND** SHALL NOT register MainWindow

### Requirement: Urban database migration on startup

The MaterialClientUrbanModule MUST execute EF Core database migration during `OnApplicationInitializationAsync`, matching MaterialClient's pattern, applying kernel context then Urban context.

#### Scenario: Successful migration
- **WHEN** `OnApplicationInitializationAsync` is called
- **THEN** the module SHALL resolve `IUnitOfWorkManager` and providers for `MaterialClientDbContext` and `UrbanDbContext`
- **AND** SHALL call `MigrateAsync` on the kernel context first
- **AND** SHALL call `MigrateAsync` on `UrbanDbContext` second
- **AND** SHALL NOT throw on migration failure (log and continue)

#### Scenario: Migration failure
- **WHEN** database migration throws an exception
- **THEN** the module SHALL log the error
- **AND** SHALL continue application startup
