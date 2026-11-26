# client-session-heartbeat Specification

## ADDED Requirements

### Requirement: Unified Client Identity Resolution

`MaterialClient.Common` SHALL provide a static `ClientIdentityResolver` used consistently across device status reporting, log pull, OTA control, and heartbeat workers so empty `Client:Id` values never suppress registration and cloned machine names can be disambiguated.

#### Scenario: Empty or whitespace Client:Id falls back cleanly

- **WHEN** `Client:Id` is null, empty, or whitespace and a `machineCode` is provided
- **THEN** `ClientIdentityResolver.Resolve` SHALL return a non-empty deterministic identifier incorporating the machine name and short machine code suffix

#### Scenario: Explicit Client:Id takes precedence

- **WHEN** `Client:Id` is explicitly configured as `"scale-west-01"`
- **THEN** `ClientIdentityResolver.Resolve` SHALL return `"scale-west-01"`

### Requirement: Periodic 30-Second Client Heartbeat and Unified Session Registration

`MaterialClient.Urban` SHALL send `RegisterSession` upon SignalR connection/reconnection and send a lightweight `ClientHeartbeat` every 30 seconds containing `ClientId`, `ProductCode`, `ProId`, `ProName`, `AppVersion`, `OtaState`, and current device status snapshots, while `DeviceStatusHub` SHALL preserve 1.0 `UploadStatus` and `RegisterLogCapability` compatibility.

#### Scenario: Heartbeat renews Redis online state and device cache without EF writes

- **WHEN** `DeviceStatusHub.ClientHeartbeat` receives a valid `ClientHeartbeatDto`
- **THEN** `DeviceStatusService.HandleHeartbeatAsync` SHALL renew the client's Redis online status and update cached device snapshots under the normalized lowercase `ProId` key without writing to EF Core

#### Scenario: Legacy 1.0 UploadStatus continues to work with normalized ProId key

- **WHEN** a 1.0 client invokes `DeviceStatusHub.UploadStatus` with an uppercase or non-canonical GUID `ProId`
- **THEN** `DeviceStatusService` SHALL normalize `ProId` to canonical lowercase GUID format before writing both connection and device Redis caches so Admin device modals find the cached devices

### Requirement: Reconnect Race Protection and Accurate Client-Side Throttling

`DeviceStatusHub.OnDisconnectedAsync` SHALL NOT mark a client offline when a newer SignalR connection has already replaced it for the same `(ProId, ClientId)`, and `DeviceStatusSignalRClient` / `DeviceStatusEventHandler` SHALL send status updates reliably after reconnect while skipping duplicate unchanged statuses within the throttle window.

#### Scenario: Stale disconnect does not mark reconnected client offline

- **GIVEN** client `("pro-1", "scale-01")` reconnected on `"conn-new"` while `"conn-old"` is still closing
- **WHEN** `OnDisconnectedAsync` fires for `"conn-old"`
- **THEN** the hub SHALL NOT call `UpsertClientDisconnectedAsync` and the client SHALL remain online

#### Scenario: Duplicate unchanged device status within throttle window is skipped

- **WHEN** `DeviceStatusEventHandler` receives two identical `(DeviceType = "Scale", Status = "Online")` events within 1 second
- **THEN** only the first event SHALL be forwarded to `IDeviceStatusSignalRClient.UploadStatusAsync`
