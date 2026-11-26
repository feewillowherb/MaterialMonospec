# client-configuration-defaults Delta Specification

## ADDED Requirements

### Requirement: Velopack-Aware Runtime Data Root Isolation

`PathManager` SHALL automatically resolve the default runtime data root (`PathManager.DataRoot`) to `<InstallRoot>\data` when running inside a Velopack layout (executable directory named `current` with `Update.exe` in its parent directory), and to `AppContext.BaseDirectory` otherwise; all runtime data, logs, local image cleanup, camera test captures, ticket exports, and optional `appsettings*.json` overrides SHALL resolve against `PathManager.DataRoot`.

#### Scenario: Velopack installation layout resolves data root to sibling data directory

- **WHEN** the executable directory is `<InstallRoot>\current` and `<InstallRoot>\Update.exe` exists
- **THEN** `PathManager.ResolveDefaultDataRoot` SHALL ensure `<InstallRoot>\data` exists and return `<InstallRoot>\data`
- **AND** SQLite database, logs, local image cleanup, and optional `appsettings*.json` overrides SHALL resolve under `<InstallRoot>\data` rather than `current`

#### Scenario: Non-Velopack layout keeps executable directory as data root

- **WHEN** the executable directory is not a Velopack `current` directory with a parent `Update.exe`
- **THEN** `PathManager.ResolveDefaultDataRoot` SHALL return the executable directory (`AppContext.BaseDirectory`)
- **AND** existing local development and portable deployments SHALL retain identical file paths

## MODIFIED Requirements

### Requirement: Clean Host appsettings Files With Explicit Exclusions

All 4 MaterialClient desktop hosts SHALL keep `appsettings.json` empty (`{}`) and exclude `appsettings.json` from publish output (`CopyToPublishDirectory="Never"`), while explicitly leaving `AliyunOss` and `Encryption:AesKey` untouched in `appsettings.secret.json` for separate follow-up handling.

#### Scenario: appsettings.json is empty and excluded from publish output

- **WHEN** inspecting `appsettings.json` and `.csproj` across `MaterialClient`, `MaterialClient.SolidWaste`, `MaterialClient.Urban`, and `MaterialClient.Recycle`
- **THEN** every `appsettings.json` SHALL be an empty JSON object `{}`
- **AND** every host `.csproj` SHALL set `<CopyToPublishDirectory>Never</CopyToPublishDirectory>` for `appsettings.json`

#### Scenario: SQLite database connection string resolves against active data root

- **WHEN** any of the 4 MaterialClient hosts initializes its EF Core SQLite DbContexts
- **THEN** the SQLite connection string SHALL resolve to `MaterialClient.db` inside `PathManager.DataRoot` (`<InstallRoot>\data` under Velopack, or `AppContext.BaseDirectory` otherwise) without requiring `ConnectionStrings:Default` in `appsettings.json`

#### Scenario: AliyunOss and Encryption:AesKey remain excluded and unchanged

- **WHEN** inspecting `appsettings.secret.json` across `MaterialClient`, `MaterialClient.SolidWaste`, and `MaterialClient.Urban`
- **THEN** existing `AliyunOss` and `Encryption:AesKey` sections SHALL remain intact and unmodified
- **AND** none of the 4 hosts' `appsettings.secret.json` SHALL contain `BasePlatform:BaseUrl`, `MaterialPlatform:BaseUrl`, or `SignalR`
