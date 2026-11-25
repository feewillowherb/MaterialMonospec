# client-configuration-defaults Specification

## Purpose
TBD - created by archiving change refactor-clean-materialclient-appsettings. Update Purpose after archive.
## Requirements
### Requirement: Centralized Built-in Configuration Defaults

MaterialClient SHALL define shared static configuration constants and built-in defaults in a single static source of truth (`MaterialClientConfigurationDefaults` in `MaterialClient.Common`) without registering new DI services, and SHALL keep all moved settings overridable via `IConfiguration` (external `appsettings*.json`, environment variables, command-line arguments, or User Secrets).

#### Scenario: StaticLicenseChecker falls back to built-in JWT public key

- **WHEN** `Jwt:PublicKey` is absent or empty in `IConfiguration`
- **THEN** `StaticLicenseChecker` SHALL load `MaterialClientConfigurationDefaults.DefaultJwtPublicKeyPem`
- **AND** JWT signature verification SHALL succeed for tokens signed by the matching issuer private key

#### Scenario: Explicit Jwt:PublicKey overrides built-in default

- **WHEN** `Jwt:PublicKey` is explicitly provided in `IConfiguration`
- **THEN** `StaticLicenseChecker` SHALL use the configured value instead of the built-in default

#### Scenario: Streets and SolidWasteTypes fall back to built-in defaults

- **WHEN** `Streets` or `SolidWasteTypes` sections are absent from `IConfiguration`
- **THEN** `MaterialClient.SolidWaste` SHALL populate `StreetsConfig` and `SolidWasteTypeConfig` from `MaterialClientConfigurationDefaults.DefaultStreets` and `MaterialClientConfigurationDefaults.DefaultSolidWasteTypes`

#### Scenario: LowPriorityPlateColors falls back only when section is absent

- **WHEN** `LowPriorityPlateColors` is absent from `IConfiguration`
- **THEN** `AttendedWeighingService` SHALL initialize `PlateNumberService` with `MaterialClientConfigurationDefaults.DefaultLowPriorityPlateColors` (`Blue`, `Green`)
- **WHEN** `LowPriorityPlateColors` is explicitly configured in `IConfiguration`
- **THEN** `AttendedWeighingService` SHALL use the explicitly configured values

### Requirement: Host-Specific Built-in Defaults and SignalR URL Derivation

Each of the 4 MaterialClient desktop hosts (`MaterialClient`, `MaterialClient.SolidWaste`, `MaterialClient.Urban`, `MaterialClient.Recycle`) SHALL embed its own default behavioral flags in code so removing redundant sections from `appsettings.json` preserves existing runtime behavior.

#### Scenario: Urban SignalR ServerUrl derived from UrbanManagement BaseUrl

- **WHEN** `SignalR:ServerUrl` is not explicitly configured in `IConfiguration` for `MaterialClient.Urban`
- **THEN** `SignalRClientOptions.ServerUrl` SHALL be derived as `{UrbanManagement:BaseUrl}/hubs/devicestatus` (normalizing trailing slashes)
- **AND** Urban SignalR reconnect defaults (`ReconnectDelays`, `MaxReconnectAttempts`, `PersistentReconnect = true`, `ReconnectResetHours = 4`, `MessageQueueSize = 100`) SHALL apply without requiring a `SignalR` block in `appsettings.json`

#### Scenario: Explicit SignalR ServerUrl overrides derivation

- **WHEN** `SignalR:ServerUrl` is explicitly configured in `IConfiguration` (e.g., via `appsettings.secret.json` or environment variable)
- **THEN** `SignalRClientOptions.ServerUrl` SHALL use the explicitly configured URL

#### Scenario: Host-specific MinimalWebHost and Polling defaults preserved

- **WHEN** `MinimalWebHost` and `BackgroundServices:Polling` are omitted from `appsettings.json`
- **THEN** `MaterialClient.Urban` SHALL default `MinimalWebHost:EnableOnStartup` to `false` and `Urban:UploadPollingPeriodMs` to `80000`
- **AND** `MaterialClient` and `MaterialClient.SolidWaste` SHALL default `BackgroundServices:Polling` to `false` and `MinimalWebHost:EnableOnStartup` to `true`
- **AND** `MaterialClient.Recycle` SHALL default `BackgroundServices:Polling` to `true` and `MinimalWebHost:EnableOnStartup` to `true`

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

