## ADDED Requirements

### Requirement: UploadStatus always touches live connection presence

When `DeviceStatusHub` / `DeviceStatusService` handles a qualifying `UploadStatus` with parseable `ProId` and non-empty `ClientId`, the server MUST Touch the live Redis connection entry for that `(ProId, ClientId)` (renew TTL/last-seen or recreate `IsConnected = true` if missing). Touch MUST NOT depend solely on “first ProId+ClientId mapping for this ConnectionId”. The system MUST NOT add a dedicated heartbeat Hub method. This change MUST NOT require MaterialClient periodic presence republish.

#### Scenario: Qualifying UploadStatus touches every time

- **WHEN** `UploadStatus` receives a message with parseable `ProId` and non-empty `ClientId`
- **THEN** the server SHALL Touch the live connection entry for that instance
- **AND** SHALL do so whether or not this ConnectionId previously stored the mapping in memory

#### Scenario: Expired live key wakes on later UploadStatus

- **WHEN** the live Redis key for `(ProId, ClientId)` has expired
- **AND** the same SignalR connection sends another qualifying `UploadStatus`
- **THEN** the server SHALL recreate live online for that instance
- **AND** client-list SHALL report `IsConnected = true` after the upload

#### Scenario: No dedicated heartbeat Hub method

- **WHEN** presence is renewed for a desktop client via SignalR
- **THEN** renewal SHALL use existing `UploadStatus`
- **AND** SHALL NOT require a new Hub RPC such as `Ping` or `Heartbeat`
