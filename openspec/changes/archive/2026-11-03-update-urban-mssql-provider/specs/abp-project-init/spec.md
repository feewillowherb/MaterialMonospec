## MODIFIED Requirements

### Requirement: Solution structure follows FluentSample template
The project SHALL consist of two source projects: `UrbanManagement.App` (Web host) and `UrbanManagement.Core` (domain layer), a one-off data import console tool `UrbanManagement.DataImport` under `tools/`, and a corresponding test project `UrbanManagement.Core.Tests`. The solution file SHALL be `UrbanManagement.sln` at the repository root.

#### Scenario: Solution file exists and contains expected projects
- **WHEN** the solution is opened
- **THEN** it SHALL contain exactly `UrbanManagement.App`, `UrbanManagement.Core`, `UrbanManagement.DataImport`, and `UrbanManagement.Core.Tests` projects

#### Scenario: App project references Core project
- **WHEN** the `UrbanManagement.App.csproj` is inspected
- **THEN** it SHALL contain a `<ProjectReference>` to `UrbanManagement.Core.csproj`

#### Scenario: Data import tool is not referenced by the web host
- **WHEN** `UrbanManagement.App.csproj` is inspected
- **THEN** it MUST NOT reference `UrbanManagement.DataImport`

## REMOVED Requirements

### Requirement: Core module configures ABP EF Core with SQLite
**Reason**: UrbanManagement moves to SQL Server as the only persistence provider.
**Migration**: See `urban-sqlserver-persistence` → "Core module configures ABP EF Core with SQL Server". Existing SQLite data is moved with `UrbanManagement.DataImport` (`urban-sqlite-to-sqlserver-import`).
