# urban-ota-control-plane Specification

## ADDED Requirements

### Requirement: Client OTA Version and Status Reporting Over DeviceStatusHub

`MaterialClient.Urban` SHALL report its current application version and Velopack OTA status to `DeviceStatusHub.ReportOtaStatus` upon initialization, after SignalR reconnection, and after OTA check/download/apply state transitions, and `DeviceStatusHub` SHALL retain online entries in memory and remove them upon disconnection.

#### Scenario: Client reports OTA status and appears in online list

- **WHEN** a connected `MaterialClient.Urban` client invokes `DeviceStatusHub.ReportOtaStatus` with its `ClientId`, `AppVersion`, and `UpdateState`
- **THEN** `IClientOtaAppService.GetOnlineClientsAsync` SHALL return an entry for that `ClientId` containing the reported `AppVersion`, `UpdateState`, `TargetVersion`, and `ReportedAtUtc`

#### Scenario: Disconnected client is removed from OTA registry

- **WHEN** the SignalR connection for a reported client disconnects
- **THEN** `DeviceStatusHub.OnDisconnectedAsync` SHALL remove that connection's entry from the in-memory OTA registry

### Requirement: Remote OTA Update Trigger With Optional Canary Feed Override

`IClientOtaAppService.TriggerUpdateAsync` SHALL push `ReceiveOtaTriggerCommand` to the target online client over SignalR (with optional `FeedUrlOverride` and `ApplyImmediatelyWhenIdle`), and `MaterialClient.Urban` SHALL execute an immediate check/download using the override feed when provided while still enforcing the `AttendedWeighingStatus.OffScale` idle gate before restarting.

#### Scenario: Triggering update for an online client dispatches SignalR command

- **GIVEN** `ClientId = "scale-01"` is registered in the OTA registry
- **WHEN** an administrator invokes `TriggerUpdateAsync` for `"scale-01"` with an optional `FeedUrlOverride`
- **THEN** the server SHALL send `ReceiveOtaTriggerCommand` to that client's `ConnectionId` and return `Accepted = true`

#### Scenario: Triggering update for an offline client returns rejected result

- **WHEN** an administrator invokes `TriggerUpdateAsync` for a `ClientId` not present in the online OTA registry
- **THEN** `TriggerUpdateAsync` SHALL return `Accepted = false` without throwing an unhandled exception

#### Scenario: Client handles remote trigger respecting idle weighing gate

- **WHEN** `ClientOtaControlService` receives `ReceiveOtaTriggerCommand` matching its `ClientId`
- **THEN** it SHALL call `IUrbanUpdateService.CheckAndDownloadUpdateAsync(feedUrlOverride)` and report updated status
- **AND** when `applyWhenIdle` is `true` and a downloaded update is ready, it SHALL call `TryApplyPendingUpdateAsync()` (which defers if weighing is active) and report the resulting state

### Requirement: Admin Client Updates Management Page

`UrbanManagement.Admin` SHALL provide a `/client-updates` page (`ClientUpdates.razor`) linked from `AdminLayout.razor` displaying online clients' versions and OTA states and allowing administrators to trigger an immediate update (with optional canary `FeedUrlOverride`) for any online client.

#### Scenario: Admin views online clients and triggers update

- **WHEN** an administrator opens `/client-updates`
- **THEN** the page SHALL display online clients' `ProjectName`, `ClientId`, `AppVersion`, `UpdateState`, `TargetVersion`, and `LastMessage`
- **AND** SHALL provide an action button to trigger an immediate update with an optional feed URL override
