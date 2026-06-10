## ADDED Requirements

### Requirement: MaterialClient solution src tests layout for build scripts

For repositories that adopt a `src/` and `tests/` solution layout (such as MaterialClient after restructuring), build configuration and packaging scripts at the solution root MUST remain valid and reference correct project and publish output paths.

#### Scenario: Directory.Build.props applies under src and tests
- **WHEN** projects live under `src/**` or `tests/**`
- **THEN** root `Directory.Build.props` SHALL still be imported automatically for those projects
- **AND** no duplicate `Directory.Build.props` is required inside `src/` unless explicitly needed

#### Scenario: Inno Setup and publish paths align with src layout
- **WHEN** `MaterialClient.iss` or `MaterialClient.Urban.iss` is maintained
- **THEN** `SourceDir` and asset paths in the script SHALL use `src\<ProjectName>\...` paths
- **AND** `dotnet publish` commands in scripts SHALL use `src/<ProjectName>/<ProjectName>.csproj` project paths
