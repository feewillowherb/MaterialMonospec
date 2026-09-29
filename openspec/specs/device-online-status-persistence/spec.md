# Device Online Status Persistence Specification

## Purpose

UrbanManagement 将桌面客户端实例在线态与设备详情当前态持久化到数据库，查询以库为准，支持同一 `ProId` 多 `ClientId`。
## Requirements
### Requirement: Client online status entity persistence

UrbanManagement MUST retain the `ClientOnlineStatus` entity and table (unique by `(ProId, ClientId)`, `ProId` as **non-nullable `Guid`**). **Live** connection state for SignalR connect/disconnect SHALL be written to Redis only on the hot path. EF rows SHALL be updated by the periodic Redis→EF snapshot job (see `urban-client-status-ef-snapshot`), not by Hub connect/disconnect. Multiple `ClientId` values per `ProId` MUST remain representable in Redis and in EF.

#### Scenario: Entity remains in DbContext

- **WHEN** the application data model is configured
- **THEN** `UrbanManagementDbContext` SHALL expose `DbSet<ClientOnlineStatus>`
- **AND** the SignalR connect/disconnect hot path SHALL NOT insert or update `ClientOnlineStatus` rows

#### Scenario: Live upsert on client instance online (Redis)

- **WHEN** a MaterialClient SignalR connection maps a valid parsed `ProId` (Guid) and non-empty `ClientId`
- **THEN** the system SHALL record that `(ProId, ClientId)` as connected in **Redis** with the short live TTL
- **AND** SHALL NOT require an EF upsert on that event

#### Scenario: Live upsert on client instance offline (Redis)

- **WHEN** the SignalR connection for a mapped `(ProId, ClientId)` disconnects
- **THEN** the system SHALL mark only that `(ProId, ClientId)` offline in **Redis** (`IsConnected = false`)
- **AND** SHALL apply the configured offline retention TTL (default seven days)
- **AND** SHALL NOT delete the connection entry solely because the client disconnected
- **AND** SHALL NOT require an EF upsert on that event

#### Scenario: Offline retention vs unregistered

- **WHEN** a disconnected Redis connection entry is still within offline retention
- **THEN** management aggregation SHALL treat that instance as registered offline (徽章「离线」)
- **WHEN** neither Redis nor EF has an entry for the project’s instances
- **THEN** the project-level badge SHALL be 未注册

### Requirement: Device online detail current-state persistence

Live device online detail for the project management device modal and `GetClientDevicesAsync` SHALL be stored in **Redis** as current-state (not an append-only audit log). The `ClientDeviceOnlineStatus` table MAY remain in the schema but the `UploadStatus` and disconnect hot paths SHALL NOT upsert that table for live state.

#### Scenario: Device detail entity MAY remain in DbContext

- **WHEN** the application data model is configured
- **THEN** `UrbanManagementDbContext` MAY continue to expose a `DbSet` for the device online detail entity
- **AND** the SignalR `UploadStatus` / disconnect hot path SHALL NOT insert or update those rows for live state

#### Scenario: Upsert on UploadStatus (Redis)

- **WHEN** a valid `UploadStatus` message includes a parseable `ProId` (Guid), `ClientId`, `DeviceType`, and `Status`
- **THEN** the system SHALL upsert the matching device detail entry in **Redis**
- **AND** SHALL NOT remove other device types or other `ClientId` entries under the same `ProId` in Redis
- **AND** SHALL NOT require an EF device-detail upsert for that event

#### Scenario: Mark devices offline on instance disconnect (Redis)

- **WHEN** a mapped `(ProId, ClientId)` SignalR connection disconnects
- **THEN** the system SHALL set those device detail entries in Redis to Offline (or equivalent) for that `(ProId, ClientId)`
- **AND** SHALL NOT change device detail entries belonging to other `ClientId` values under the same `ProId`

#### Scenario: Device details do not survive Redis loss

- **WHEN** Redis live device keys are missing after restart/flush/eviction
- **THEN** `GetClientDevicesAsync` SHALL return empty or offline-equivalent live data from Redis
- **AND** SHALL NOT be required to return historical SQLite device-detail rows as live state

### Requirement: Project-level aggregation for management UI

When the project management UI needs a single status per project, the system MUST aggregate all connection instances for that `ProId` from the Redis-preferred merged set (Redis hits plus EF offline fallbacks) without collapsing them in storage.

#### Scenario: Aggregate online

- **WHEN** at least one Redis connection entry for the `ProId` is connected
- **THEN** the project-level client badge SHALL be 在线

#### Scenario: Aggregate offline

- **WHEN** the merged instance set for the `ProId` is non-empty and every instance is disconnected (including EF fallbacks)
- **THEN** the project-level client badge SHALL be 离线

#### Scenario: Aggregate unregistered

- **WHEN** the merged instance set for the `ProId` is empty
- **THEN** the project-level client badge SHALL be 未注册

### Requirement: LastSeenAt refresh without dedicated heartbeat

The system SHALL refresh last-seen (and Redis key TTL) on qualifying `UploadStatus` messages that carry `ProId` and `ClientId` when a live Redis connection entry exists, without introducing a separate heartbeat Hub method. The refresh MUST support an optional minimum interval throttle. This refresh SHALL NOT require updating SQLite `ClientOnlineStatus.LastSeenAt` on the hot path.

#### Scenario: Status upload refreshes last-seen in Redis

- **WHEN** an `UploadStatus` message includes known `ProId` and `ClientId` and a live Redis connection entry exists
- **THEN** the system SHALL update that entry's last-seen subject to an optional throttle
- **AND** SHALL refresh the Redis TTL for that live entry
- **AND** SHALL NOT require a new MaterialClient heartbeat protocol

#### Scenario: Missing ClientId does not fall back to ProId-only upsert

- **WHEN** an `UploadStatus` that would register online or device detail lacks a usable `ClientId`
- **THEN** the system SHALL NOT upsert a ProId-only live connection or device entry that would violate multi-instance uniqueness
- **AND** SHALL log a warning or error for diagnostics

### Requirement: Weighing receive touches live online presence

After a successful `ReceiveAsync` (including Legacy ingest that delegates to `ReceiveAsync`), UrbanManagement MUST Touch live online presence when a usable instance `ClientId` is available, using the same Touch semantics as SignalR (renew or recreate). Legacy clients that have no SignalR SHALL become visible as online through this path alone.

#### Scenario: Legacy Post marks project instance online

- **WHEN** a Legacy `/Api/Post` request is accepted and `ReceiveAsync` succeeds for a registered AccessCode
- **THEN** the system SHALL Touch live online for `ProId` = the resolved project id
- **AND** `ClientId` SHALL be exactly `legacy:{AccessCode}` where `{AccessCode}` is the normalized project access code used for lookup
- **AND** subsequent client-list / project badge aggregation SHALL treat that instance as connected while the live TTL remains valid

#### Scenario: Modern receive with SubmitMachineCode touches online

- **WHEN** `ReceiveAsync` succeeds and `SubmitMachineCode` is non-empty
- **THEN** the system SHALL Touch live online for that `ProId` with `ClientId` = `SubmitMachineCode`
- **AND** SHALL renew or recreate the live entry as for SignalR Touch

#### Scenario: Modern receive without SubmitMachineCode skips presence touch

- **WHEN** `ReceiveAsync` succeeds and `SubmitMachineCode` is null or whitespace
- **THEN** the system SHALL NOT invent a ProId-only live connection row
- **AND** SHALL leave SignalR-based presence unchanged by this receive

### Requirement: Redis is authoritative for live connection and device-detail queries

Client connection queries used for management badges MUST prefer live state from Redis. When Redis has no entry for an instance that exists in `ClientOnlineStatus`, the query SHALL fall back to EF and present that instance as **offline** for badge aggregation (MUST NOT promote a Redis-miss EF row to 在线). Device online detail queries MAY fall back to EF device-detail rows when Redis misses if those rows were populated by the snapshot job; otherwise empty Redis remains empty.

#### Scenario: Connection query when Redis has entries

- **WHEN** live connection entries exist in Redis for a `ProId`
- **THEN** `GetClientListAsync` (or equivalent) SHALL return those instance state(s) from Redis

#### Scenario: Connection query Redis miss with EF history

- **WHEN** Redis has no connection entry for a `(ProId, ClientId)` that exists in `ClientOnlineStatus`
- **THEN** the query SHALL include that instance as disconnected/offline for aggregation
- **AND** SHALL preserve last-seen / disconnect timestamps from EF when available
- **AND** SHALL NOT treat Redis-miss EF `IsConnected = true` as 在线

#### Scenario: Connection query when Redis and EF both miss

- **WHEN** neither Redis nor EF has connection rows for a `ProId`
- **THEN** the project-level client badge SHALL be 未注册

#### Scenario: Device detail query when Redis misses

- **WHEN** Redis device-detail entries for a `ProId` are missing
- **THEN** `GetClientDevicesAsync` MAY return snapshot-backed EF device-detail rows when available
- **AND** SHALL NOT invent device rows that were never snapshotted or uploaded

