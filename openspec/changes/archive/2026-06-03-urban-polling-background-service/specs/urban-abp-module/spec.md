## MODIFIED Requirements

### Requirement: MaterialClientUrbanModule AbpModule definition

The system SHALL define a `MaterialClientUrbanModule` class that extends `AbpModule` with the following dependencies: `MaterialClientCommonModule`, `AbpAutofacModule`. This module MUST NOT depend on `MaterialClientModule` (the main app module).

#### Scenario: Module dependency chain
- **WHEN** the ABP application initializes with `MaterialClientUrbanModule`
- **THEN** the module SHALL depend on `MaterialClientCommonModule` (provides EF Core, DbContext, entities)
- **AND** SHALL depend on `AbpAutofacModule` (provides Autofac DI container)
- **AND** MUST NOT depend on `MaterialClientModule`

#### Scenario: Service configuration
- **WHEN** `ConfigureServices` is called during ABP initialization
- **THEN** the module SHALL configure Serilog logging with daily rotation (matching MaterialClient's pattern)
- **AND** SHALL NOT register Refit API clients (Urban has no platform API)
- **AND** SHALL NOT register `MaterialClient.Backgrounds.PollingBackgroundService` or `MinimalWebHostService`
- **AND** SHALL NOT register MainWindow

## ADDED Requirements

### Requirement: Urban background worker registration

When Urban background polling is enabled, `MaterialClientUrbanModule` SHALL register the Urban-specific `MaterialClient.Urban.Backgrounds.PollingBackgroundService` and SHALL depend on `AbpBackgroundWorkersModule`.

#### Scenario: Urban polling worker registered
- **WHEN** `BackgroundServices:Polling` is `true` in configuration
- **THEN** the module SHALL depend on `AbpBackgroundWorkersModule`
- **AND** SHALL register `MaterialClient.Urban.Backgrounds.PollingBackgroundService` as a background worker
- **AND** MUST NOT register any type from the `MaterialClient.Backgrounds` namespace of the main `MaterialClient` project

#### Scenario: Urban polling worker not registered when disabled
- **WHEN** `BackgroundServices:Polling` is `false`
- **THEN** the module SHALL NOT register `MaterialClient.Urban.Backgrounds.PollingBackgroundService`
