## ADDED Requirements

### Requirement: Solution structure follows FluentSample template
The project SHALL consist of two source projects: `UrbanManagement.App` (Web host) and `UrbanManagement.Core` (domain layer), with a corresponding test project `UrbanManagement.Core.Tests`. The solution file SHALL be `UrbanManagement.sln` at the repository root.

#### Scenario: Solution file exists and contains expected projects
- **WHEN** the solution is opened
- **THEN** it SHALL contain exactly `UrbanManagement.App`, `UrbanManagement.Core`, and `UrbanManagement.Core.Tests` projects

#### Scenario: App project references Core project
- **WHEN** the `UrbanManagement.App.csproj` is inspected
- **THEN** it SHALL contain a `<ProjectReference>` to `UrbanManagement.Core.csproj`

### Requirement: Directory.Build.props configures unified build settings
A `Directory.Build.props` file at the solution root SHALL set `TargetFramework` to `net10.0`, enable `Nullable`, enable `ImplicitUsings`, and include the `AutoConstructor` source generator for all projects.

#### Scenario: All projects target .NET 10
- **WHEN** any project in the solution is built
- **THEN** it SHALL compile against `net10.0`

#### Scenario: AutoConstructor is available in all projects
- **WHEN** any C# file uses `[AutoConstructor]` attribute
- **THEN** the source generator SHALL produce the constructor without compilation errors

### Requirement: Directory.Packages.props enables Central Package Management
A `Directory.Packages.props` file SHALL define all NuGet package versions centrally using `<ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>`. Individual project files SHALL reference packages without version numbers.

#### Scenario: Package versions are consistent across projects
- **WHEN** both App and Core reference the same ABP package
- **THEN** both SHALL resolve to the same version defined in Directory.Packages.props

### Requirement: Core module configures ABP EF Core with SQLite
`UrbanManagementCoreModule` SHALL depend on `AbpEntityFrameworkCoreModule` and `AbpEntityFrameworkCoreSqliteModule`, register `UrbanManagementDbContext` with `AddDefaultRepositories(true)`, and configure SQLite connection string.

#### Scenario: DbContext is registered with ABP
- **WHEN** the application starts
- **THEN** `UrbanManagementDbContext` SHALL be available through ABP's repository pattern

### Requirement: App module depends on Core and Autofac
`UrbanManagementAppModule` SHALL depend on `UrbanManagementCoreModule` and `AbpAutofacModule`.

#### Scenario: ABP module chain is valid
- **WHEN** the application starts
- **THEN** the module dependency chain SHALL be: AppModule → CoreModule → AbpEntityFrameworkCoreModule
