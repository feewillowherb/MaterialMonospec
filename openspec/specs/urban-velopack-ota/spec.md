# urban-velopack-ota Specification

## Purpose
TBD - created by archiving change add-urban-velopack-ota. Update Purpose after archive.
## Requirements
### Requirement: Velopack Lifecycle Bootstrap Before Single-Instance Mutex

`MaterialClient.Urban` SHALL invoke `VelopackApp.Build().Run()` at the entry of `Program.Main` before acquiring the single-instance `Mutex` or initializing Avalonia.

#### Scenario: Velopack hook invocation executes before Mutex acquisition

- **WHEN** `MaterialClient.Urban.exe` starts
- **THEN** `VelopackApp.Build().Run()` SHALL execute prior to creating `MaterialClient_Urban_SingleInstance_Mutex`

### Requirement: OTA Feed URL Resolution and Configuration Options

`MaterialClientConfigurationDefaults` SHALL resolve the Urban OTA feed URL from an explicit `Ota:FeedUrl` when configured, or derive `{UrbanManagement:BaseUrl}/updates/urban` otherwise, and `OtaOptions` SHALL bind from the `Ota` configuration section with safe defaults (`Enabled = true`, `CheckIntervalMinutes = 30`, `AutoApplyWhenIdle = true`).

#### Scenario: Explicit Ota:FeedUrl overrides derived URL

- **WHEN** `Ota:FeedUrl` is configured (HTTP URL or local directory path)
- **THEN** `ResolveOtaFeedUrl` SHALL return the trimmed configured value

#### Scenario: Missing Ota:FeedUrl derives from UrbanManagement:BaseUrl

- **WHEN** `Ota:FeedUrl` is null or whitespace and `UrbanManagement:BaseUrl` is `http://191.12.234.212:5233/`
- **THEN** `ResolveOtaFeedUrl` SHALL return `http://191.12.234.212:5233/updates/urban`

### Requirement: Weighing Idle Readiness Gate and Graceful Non-Installed Degradation

`IUrbanUpdateService` SHALL gracefully report `NotInstalled` without throwing when running outside a Velopack installation, and SHALL refuse to apply a downloaded update while the weighing state is not `AttendedWeighingStatus.OffScale`.

#### Scenario: Non-Velopack execution degrades gracefully

- **WHEN** `CheckAndDownloadUpdateAsync` is called in a non-Velopack environment (`IsInstalled == false`)
- **THEN** the service SHALL return a `NotInstalled` result without throwing exceptions or modifying local files

#### Scenario: Active weighing blocks update restart

- **GIVEN** a downloaded pending update is ready
- **WHEN** `IAttendedWeighingService.GetCurrentStatus()` is not `AttendedWeighingStatus.OffScale`
- **THEN** `TryApplyPendingUpdateAsync` SHALL NOT restart the application and SHALL return a deferred-not-idle result

#### Scenario: Idle weighing permits update restart and writes updating lock

- **GIVEN** a downloaded pending update is ready
- **WHEN** `IAttendedWeighingService.GetCurrentStatus()` is `AttendedWeighingStatus.OffScale`
- **THEN** `TryApplyPendingUpdateAsync` SHALL write `.updating.lock` under `PathManager.DataRoot` and invoke the Velopack apply-and-restart action

