# urban-velopack-ota Delta Specification

## ADDED Requirements

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
