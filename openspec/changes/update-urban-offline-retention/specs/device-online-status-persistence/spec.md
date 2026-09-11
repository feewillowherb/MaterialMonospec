## MODIFIED Requirements

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
