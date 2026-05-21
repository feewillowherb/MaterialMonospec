# Urban ABP Module Specification

## Purpose

定义 MaterialClient.Urban 应用的 ABP 模块集成规范，包括模块定义、ABP 工厂启动、项目配置、关闭生命周期、静态授权检查和数据库迁移。

## Requirements

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
- **AND** SHALL NOT register PollingBackgroundService or MinimalWebHostService
- **AND** SHALL NOT register MainWindow

### Requirement: Urban application startup via ABP factory

The MaterialClient.Urban `App.axaml.cs` MUST use `AbpApplicationFactory.CreateAsync<MaterialClientUrbanModule>()` to initialize the application, replacing the current manual `ServiceCollection` approach.

#### Scenario: ABP application creation
- **WHEN** `App.OnFrameworkInitializationCompleted` is called
- **THEN** the app SHALL call `AbpApplicationFactory.CreateAsync<MaterialClientUrbanModule>(options => options.UseAutofac())`
- **AND** SHALL call `InitializeAsync()` on the resulting application
- **AND** SHALL NOT create a manual `ServiceCollection`

#### Scenario: Window creation from ABP container
- **WHEN** ABP initialization completes successfully
- **THEN** the app SHALL resolve `UrbanAttendedWeighingWindow` from the ABP service provider
- **AND** SHALL set it as `desktop.MainWindow`
- **AND** SHALL register `desktop.Exit` handler for cleanup

#### Scenario: ABP initialization failure
- **WHEN** ABP initialization throws an exception
- **THEN** the app SHALL log the error
- **AND** SHALL call `desktop.Shutdown()`

### Requirement: Urban ABP project file configuration

The `MaterialClient.Urban.csproj` MUST include ABP NuGet package references required for module functionality.

#### Scenario: Package references
- **WHEN** the project is built
- **THEN** the csproj SHALL reference `Volo.Abp.Autofac` package
- **AND** SHALL reference `Volo.Abp.Core` package (transitive via MaterialClient.Common, but explicit is acceptable)
- **AND** SHALL continue referencing `MaterialClient.Common` project

### Requirement: Urban application shutdown with ABP lifecycle

The MaterialClient.Urban `App.axaml.cs` MUST follow the AGENTS.md exit order: stop hardware devices -> shutdown ABP -> flush Serilog.

#### Scenario: Normal shutdown
- **WHEN** the user closes the application window
- **THEN** the app SHALL dispose the ViewModel
- **AND** SHALL close any hardware devices (if registered)
- **AND** SHALL call `ShutdownAsync()` on the ABP application
- **AND** SHALL dispose the ABP application
- **AND** SHALL flush and close Serilog

#### Scenario: Shutdown timeout protection
- **WHEN** the shutdown sequence takes longer than 10 seconds
- **THEN** the app SHALL log a warning and force exit

### Requirement: Urban static license check during ABP initialization

The static license check MUST run during `OnApplicationInitializationAsync` of the Urban module, not as a fire-and-forget task.

#### Scenario: License check execution
- **WHEN** `OnApplicationInitializationAsync` is called
- **THEN** the module SHALL resolve `IStaticLicenseChecker` from the service provider
- **AND** SHALL execute the license check asynchronously
- **AND** SHALL log the result (success or failure)
- **AND** MUST NOT block application startup on check failure

#### Scenario: License check failure
- **WHEN** the static license check fails
- **THEN** the module SHALL log a warning
- **AND** SHALL continue application startup (non-blocking)

### Requirement: Urban database migration on startup

The MaterialClientUrbanModule MUST execute EF Core database migration during `OnApplicationInitializationAsync`, matching MaterialClient's pattern.

#### Scenario: Successful migration
- **WHEN** `OnApplicationInitializationAsync` is called
- **THEN** the module SHALL resolve `IUnitOfWorkManager` and `IDbContextProvider<MaterialClientDbContext>`
- **AND** SHALL call `dbContext.Database.MigrateAsync()`
- **AND** SHALL NOT throw on migration failure (log and continue)

#### Scenario: Migration failure
- **WHEN** database migration throws an exception
- **THEN** the module SHALL log the error
- **AND** SHALL continue application startup
