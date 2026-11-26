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

### Requirement: Startup Health Tracking After 30 Seconds of Stable Operation

`MaterialClient.Urban` SHALL persist startup health metadata in `PathManager.DataRoot\.ota-health.json` via `OtaStartupHealthTracker`, recording each startup attempt and marking the active version healthy after 30 seconds of uninterrupted operation; corrupted or unreadable health files SHALL NOT block startup.

#### Scenario: Stable startup marks version healthy after threshold

- **WHEN** `OtaStartupHealthTracker.RecordStartup` is called for version `2.0.2` and `OtaStartupHealthTracker.MarkHealthy` is subsequently called
- **THEN** `.ota-health.json` SHALL record `IsHealthy = true` and `ConsecutiveUnhealthyStarts = 0`

#### Scenario: Repeated crashes without reaching healthy threshold flag ThresholdExceeded

- **WHEN** `OtaStartupHealthTracker.RecordStartup` is called 3 consecutive times for version `2.0.2` without an intervening `MarkHealthy`
- **THEN** the returned `OtaHealthState` SHALL report `ConsecutiveUnhealthyStarts = 3` and `ThresholdExceeded = true`

#### Scenario: Corrupted health file does not throw on startup

- **WHEN** `.ota-health.json` contains malformed JSON
- **THEN** `OtaStartupHealthTracker.RecordStartup` SHALL recover cleanly and overwrite it with a valid state record without throwing

### Requirement: Standardized Packaging and Watchdog Exclusion Scripts

`repos/MaterialClient/scripts/` SHALL provide `pack-urban-ota.ps1` (enforcing `--runtime win-x64` and asserting `appsettings.json` is absent from publish output), `urban-watchdog-tick.ps1` (skipping relaunch while a fresh `data\.updating.lock` exists), and `install-urban-watchdog.ps1` (registering and uninstalling the interactive Windows Scheduled Task watchdog).

#### Scenario: Watchdog tick skips relaunch during active OTA update lock

- **WHEN** `urban-watchdog-tick.ps1` runs and `<InstallRoot>\data\.updating.lock` exists within the lock timeout window
- **THEN** the script SHALL exit without launching `MaterialClient.Urban.exe`

