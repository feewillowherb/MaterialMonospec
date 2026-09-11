## MODIFIED Requirements

### Requirement: Client online status entity persistence

UrbanManagement MAY retain the `ClientOnlineStatus` entity and table (unique by `(ProId, ClientId)`, `ProId` as **non-nullable `Guid`**) for schema compatibility, but **live** connection state for SignalR connect/disconnect SHALL **NOT** be upserted into that table. Live connection state SHALL be stored in Redis (see `urban-redis-distributed-cache`). Multiple `ClientId` values per `ProId` MUST still be representable in the live Redis model.

#### Scenario: Entity MAY remain in DbContext

- **WHEN** the application data model is configured
- **THEN** `UrbanManagementDbContext` MAY continue to expose `DbSet<ClientOnlineStatus>`
- **AND** this change SHALL NOT require dropping the table
- **AND** the SignalR connect/disconnect hot path SHALL NOT insert or update `ClientOnlineStatus` rows

#### Scenario: Optional Slot column reserved for Urban V2

- **WHEN** the `ClientOnlineStatus` table exists
- **THEN** the entity MAY include a nullable `Slot` (`int?`)
- **AND** this change SHALL NOT require writing `Slot` on connect/disconnect
- **AND** `Slot` SHALL NOT be treated as the authorization source of truth

#### Scenario: Live upsert on client instance online (Redis)

- **WHEN** a MaterialClient SignalR connection maps a valid parsed `ProId` (Guid) and non-empty `ClientId`
- **THEN** the system SHALL record that `(ProId, ClientId)` as connected in **Redis**
- **AND** SHALL set connected / last-seen timestamps in the Redis payload (or equivalent)
- **AND** SHALL update `ProName` in Redis when provided
- **AND** SHALL NOT delete or overwrite other `ClientId` live entries under the same `ProId`
- **AND** SHALL NOT require an EF upsert to `ClientOnlineStatus` for that event

#### Scenario: Live upsert on client instance offline (Redis)

- **WHEN** the SignalR connection for a mapped `(ProId, ClientId)` disconnects
- **THEN** the system SHALL mark only that `(ProId, ClientId)` offline (or remove its online key) in **Redis**
- **AND** SHALL NOT mark other instances under the same `ProId` as offline
- **AND** SHALL NOT require an EF upsert to `ClientOnlineStatus` for that event

#### Scenario: Multiple instances under one project (live)

- **WHEN** two different `ClientId` values under the same `ProId` are both connected
- **THEN** Redis SHALL contain two distinct live connection entries for that `ProId`
- **AND** both SHALL be treated as connected for aggregation

#### Scenario: Connection loss on Redis or process restart is accepted

- **WHEN** Redis is flushed/restarted or live keys expire/are evicted
- **THEN** the system SHALL treat missing live entries as offline or unregistered for management UI queries
- **AND** SHALL NOT be required to restore prior connection state from SQLite
- **AND** desktop clients MUST re-register by reconnecting to restore live state

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

### Requirement: Redis is authoritative for live connection and device-detail queries

Client connection queries used for management badges MUST read live state from Redis. Device online detail queries (`GetClientDevicesAsync` and equivalents) MUST read live state from Redis. SQLite MUST NOT be the sole or fallback source of truth for **live** badges and device modals after this change.

#### Scenario: Connection query when Redis has entries

- **WHEN** live connection entries exist in Redis for a `ProId`
- **THEN** `GetClientListAsync` (or equivalent) SHALL return those instance state(s) from Redis

#### Scenario: Connection query when Redis misses

- **WHEN** no live connection entries exist in Redis for a `ProId`
- **THEN** the project-level client badge SHALL be 未注册 or 离线 per aggregation rules over the empty live set
- **AND** the query SHALL NOT fall back to `ClientOnlineStatus` SQLite rows to fabricate live online state

#### Scenario: Device detail query when Redis misses

- **WHEN** Redis device-detail entries for a `ProId` are missing
- **THEN** `GetClientDevicesAsync` SHALL NOT be required to return SQLite `ClientDeviceOnlineStatus` rows as live data

### Requirement: Project-level aggregation for management UI

When the project management UI needs a single status per project, the system MUST aggregate all **live Redis** connection entries for that `ProId` without collapsing them in storage. Live device detail entries drive the device modal, not the project-level 未注册/在线/离线 badge.

#### Scenario: Aggregate online

- **WHEN** at least one live Redis connection entry for the `ProId` is connected
- **THEN** the project-level client badge SHALL be 在线

#### Scenario: Aggregate offline

- **WHEN** the `ProId` has one or more live Redis connection entries and every entry is disconnected
- **THEN** the project-level client badge SHALL be 离线

#### Scenario: Aggregate unregistered

- **WHEN** the `ProId` has no live Redis connection entries
- **THEN** the project-level client badge SHALL be 未注册

#### Scenario: Aggregate last online time

- **WHEN** the project table renders「最后在线时间」
- **THEN** the value SHALL be derived from the newest relevant timestamp among that `ProId`'s live Redis connection entries
- **AND** SHALL NOT use `GovProject.LastSyncTime`

#### Scenario: Device modal uses live Redis details

- **WHEN** the user opens the project「设备」modal for a `ProId`
- **THEN** the UI SHALL render device cards from `GetClientDevicesAsync` backed by live Redis device detail entries
- **AND** SHALL show status and last update time per device type (and per `ClientId` when multiple instances exist)

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
