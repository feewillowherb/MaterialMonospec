# client-configuration-defaults Delta Specification

## ADDED Requirements

### Requirement: Environment-Aware Default Service Endpoints

`MaterialClientConfigurationDefaults` SHALL define built-in default service endpoint URLs using `#if DEBUG` (test/local endpoints) and `#else` / Release (production endpoints), and all Refit / HttpClient registrations (`RefitClientRegistrationExtensions`, `MaterialClientUrbanModule`, `MaterialClientRecycleModule`) SHALL fall back to these defaults when `IConfiguration` does not specify a non-empty URL.

#### Scenario: Release build defaults to production endpoints without appsettings.json

- **WHEN** running a `Release` build with no `BasePlatform:BaseUrl`, `MaterialPlatform:BaseUrl`, or `UrbanManagement:BaseUrl` configured
- **THEN** `BasePlatform:BaseUrl` SHALL default to `http://base.publicapi.findong.com`
- **AND** `MaterialPlatform:BaseUrl` SHALL default to `http://mt.publicapi.findong.com`
- **AND** `UrbanManagement:BaseUrl` SHALL default to `http://191.12.234.212:5233`
- **AND** Urban `SignalRClientOptions.ServerUrl` SHALL derive `http://191.12.234.212:5233/hubs/devicestatus`

#### Scenario: Debug build defaults to test/local endpoints to prevent accidental production writes

- **WHEN** running a `Debug` build with no service URLs configured
- **THEN** `BasePlatform:BaseUrl` SHALL default to `http://192.168.3.135:8551`
- **AND** `MaterialPlatform:BaseUrl` SHALL default to `http://localhost:5000`
- **AND** `UrbanManagement:BaseUrl` SHALL default to `http://192.168.3.138:5333`

#### Scenario: Explicit appsettings.json URL overrides built-in default without secret.json shadowing

- **WHEN** an operator or tester places an `appsettings.json` specifying `BasePlatform:BaseUrl`, `MaterialPlatform:BaseUrl`, `UrbanManagement:BaseUrl`, or `RecycleSync:ApiUrl`
- **THEN** the configured URL SHALL override the built-in default
- **AND** `appsettings.secret.json` SHALL NOT contain `BasePlatform:BaseUrl` or `MaterialPlatform:BaseUrl` that would shadow `appsettings.json`

## MODIFIED Requirements

### Requirement: Clean Host appsettings Files With Explicit Exclusions

All 4 MaterialClient desktop hosts SHALL keep `appsettings.json` empty (`{}`) and exclude `appsettings.json` from publish output (`CopyToPublishDirectory="Never"`), while explicitly leaving `AliyunOss` and `Encryption:AesKey` untouched in `appsettings.secret.json` for separate follow-up handling.

#### Scenario: appsettings.json is empty and excluded from publish output

- **WHEN** inspecting `appsettings.json` and `.csproj` across `MaterialClient`, `MaterialClient.SolidWaste`, `MaterialClient.Urban`, and `MaterialClient.Recycle`
- **THEN** every `appsettings.json` SHALL be an empty JSON object `{}`
- **AND** every host `.csproj` SHALL set `<CopyToPublishDirectory>Never</CopyToPublishDirectory>` for `appsettings.json`

#### Scenario: SQLite database connection string is pinned to executable directory

- **WHEN** any of the 4 MaterialClient hosts initializes its EF Core SQLite DbContexts
- **THEN** the SQLite connection string SHALL resolve to `MaterialClient.db` inside `AppContext.BaseDirectory` (the executable directory) via `MaterialClientConfigurationDefaults.ResolveExeDirectoryConnectionString()` without requiring `ConnectionStrings:Default` in `appsettings.json`

#### Scenario: AliyunOss and Encryption:AesKey remain excluded and unchanged

- **WHEN** inspecting `appsettings.secret.json` across `MaterialClient`, `MaterialClient.SolidWaste`, and `MaterialClient.Urban`
- **THEN** existing `AliyunOss` and `Encryption:AesKey` sections SHALL remain intact and unmodified
- **AND** none of the 4 hosts' `appsettings.secret.json` SHALL contain `BasePlatform:BaseUrl`, `MaterialPlatform:BaseUrl`, or `SignalR`
