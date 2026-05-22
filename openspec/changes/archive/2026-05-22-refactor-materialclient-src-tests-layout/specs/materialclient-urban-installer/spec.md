## ADDED Requirements

### Requirement: MaterialClient.Urban Inno Setup installer script

The MaterialClient repository MUST provide an Inno Setup script `MaterialClient.Urban.iss` at repository root that packages the Urban desktop application publish output, modeled after `MaterialClient.iss`.

#### Scenario: Urban iss file exists
- **WHEN** the MaterialClient repository root is inspected
- **THEN** SHALL exist `MaterialClient.Urban.iss`
- **AND** it SHALL be separate from `MaterialClient.iss` with a distinct `AppId` GUID

#### Scenario: Urban installer packages publish output
- **WHEN** Inno Setup compiles `MaterialClient.Urban.iss` after `dotnet publish` for Urban
- **THEN** the installer SHALL include `MaterialClient.Urban.exe` from `src\MaterialClient.Urban\bin\Release\net10.0\win-x64\publish`
- **AND** SHALL include `appsettings.json` and `appsettings.secret.json` with `onlyifdoesntexist` flags matching main app behavior
- **AND** output SHALL be written to `Installer/` as `MaterialClient.Urban_Setup_<version>.exe` (or documented equivalent)

#### Scenario: Urban installer metadata
- **WHEN** the Urban installer is built
- **THEN** `MyAppExeName` SHALL be `MaterialClient.Urban.exe`
- **AND** `SetupIconFile` SHALL use `src\MaterialClient.Urban\Assets\fd-ico.ico`
- **AND** installer SHALL require x64 Windows 10+ consistent with main app script
- **AND** default install directory SHALL NOT collide with main `MaterialClient` install folder (distinct `DefaultDirName` or display name)

#### Scenario: Urban publish prerequisite documented
- **WHEN** a release engineer prepares the Urban installer
- **THEN** documentation or `publish-urban.cmd` SHALL define the `dotnet publish` command for `src/MaterialClient.Urban/MaterialClient.Urban.csproj` with `Release`, `win-x64`, `PublishSingleFile`, and `self-contained` flags matching main app publish settings
