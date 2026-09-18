# Device Online Status Persistence Specification

## Purpose

UrbanManagement 将桌面客户端实例在线态与设备详情当前态持久化到数据库，查询以库为准，支持同一 `ProId` 多 `ClientId`。

## Requirements

### Requirement: Client online status entity persistence

UrbanManagement MUST persist each desktop client instance's current online/offline connection state in the database via a `ClientOnlineStatus` entity that is unique by `(ProId, ClientId)`, registered on `UrbanManagementDbContext` with an EF Core migration. The schema MUST allow multiple rows per `ProId` so a future Urban V2 project can keep up to four concurrent machine instances online without a table redesign. `ProId` SHALL be stored as **non-nullable `Guid`**.

#### Scenario: Entity stored in DbContext

- **WHEN** the application data model is configured
- **THEN** `UrbanManagementDbContext` SHALL expose a `DbSet` for `ClientOnlineStatus`
- **AND** the entity SHALL include at least `ProId` (**Guid**), `ClientId`, `ProName`, `IsConnected`, `ConnectedAt`, `DisconnectedAt`, and `LastSeenAt`
- **AND** `(ProId, ClientId)` SHALL be unique
- **AND** `ProId` alone MUST NOT be a uniqueness constraint that would allow only one row per project

#### Scenario: Optional Slot column reserved for Urban V2

- **WHEN** the `ClientOnlineStatus` table is created
- **THEN** the entity MAY include a nullable `Slot` (`int?`) for future correlation with Urban V2 machine-code slots
- **AND** this change SHALL NOT require writing `Slot` on connect/disconnect
- **AND** `Slot` SHALL NOT be treated as the authorization source of truth

#### Scenario: Upsert on client instance online

- **WHEN** a MaterialClient SignalR connection maps a valid parsed `ProId` (Guid) and non-empty `ClientId` (online registration for that instance)
- **THEN** the system SHALL upsert `ClientOnlineStatus` for that `(ProId, ClientId)` with `IsConnected = true`
- **AND** SHALL set `ConnectedAt` and `LastSeenAt` to the write-path clock
- **AND** SHALL update `ProName` when provided
- **AND** SHALL NOT delete or overwrite other `ClientId` rows under the same `ProId`

#### Scenario: Upsert on client instance offline

- **WHEN** the SignalR connection for a mapped `(ProId, ClientId)` disconnects
- **THEN** the system SHALL upsert only that `(ProId, ClientId)` row with `IsConnected = false`
- **AND** SHALL set `DisconnectedAt` and update `LastSeenAt`
- **AND** SHALL NOT mark other instances under the same `ProId` as offline

#### Scenario: Multiple instances under one project

- **WHEN** two different `ClientId` values under the same `ProId` are both connected
- **THEN** the database SHALL contain two `ClientOnlineStatus` rows for that `ProId`
- **AND** both rows SHALL have `IsConnected = true`

#### Scenario: Survives process restart

- **WHEN** UrbanManagement restarts after clients were connected
- **THEN** persisted `ClientOnlineStatus` rows SHALL remain queryable from the database

#### Scenario: Migration ignores unparseable historical ProId rows

- **WHEN** an EF migration converts `ClientOnlineStatus.ProId` from string to Guid
- **THEN** rows whose legacy `ProId` value cannot be parsed as Guid SHALL be removed from the table
- **AND** the migration MUST NOT attempt to infer or repair invalid project identifiers

### Requirement: Device online detail current-state persistence

UrbanManagement MUST persist the latest online detail for each device type on each client instance via a `ClientDeviceOnlineStatus` entity (name may vary) that is unique by `(ProId, ClientId, DeviceType)`, registered on `UrbanManagementDbContext` with an EF Core migration. `ProId` SHALL be **non-nullable `Guid`**. This is current-state storage for the project management device modal and `GetClientDevicesAsync`, not an append-only audit log.

#### Scenario: Device detail entity in DbContext

- **WHEN** the application data model is configured
- **THEN** `UrbanManagementDbContext` SHALL expose a `DbSet` for the device online detail entity
- **AND** each row SHALL include at least `ProId` (**Guid**), `ClientId`, `DeviceType`, `Status`, `LastUpdateTime`, and optional `AdditionalData`
- **AND** `(ProId, ClientId, DeviceType)` SHALL be unique

#### Scenario: Upsert on UploadStatus

- **WHEN** a valid `UploadStatus` message includes a parseable `ProId` (Guid), `ClientId`, `DeviceType`, and `Status`
- **THEN** the system SHALL upsert the matching device detail row with that status and timestamp
- **AND** SHALL NOT remove other device types or other `ClientId` rows under the same `ProId`

#### Scenario: Mark devices offline on instance disconnect

- **WHEN** a mapped `(ProId, ClientId)` SignalR connection disconnects
- **THEN** the system SHALL set `Status` to Offline (or equivalent) for all device detail rows of that `(ProId, ClientId)`
- **AND** SHALL update their `LastUpdateTime`
- **AND** SHALL NOT change device detail rows belonging to other `ClientId` values under the same `ProId`

#### Scenario: Device details survive restart

- **WHEN** UrbanManagement restarts after device statuses were persisted
- **THEN** `GetClientDevicesAsync` SHALL return persisted device detail rows from the database

### Requirement: Database is authoritative for connection and device-detail queries

Client connection queries MUST read from `ClientOnlineStatus`. Device online detail queries (`GetClientDevicesAsync` and equivalents) MUST read from the device detail current-state table. Distributed cache MUST NOT be the sole source of truth.

#### Scenario: Connection query after cache expiry

- **WHEN** connection cache entries have expired or are missing
- **AND** one or more `ClientOnlineStatus` rows exist for a `ProId`
- **THEN** `GetClientListAsync` (or equivalent) SHALL still return the persisted instance state(s) from the database

#### Scenario: Device detail query after cache expiry

- **WHEN** `DeviceStatusCacheItem` for a `ProId` is missing
- **AND** device detail rows exist for that `ProId`
- **THEN** `GetClientDevicesAsync` SHALL return those rows from the database
- **AND** each item SHALL include enough identity to distinguish instances (`ClientId`) when multiple instances exist

#### Scenario: Optional write-through cache

- **WHEN** the system upserts connection or device detail rows
- **THEN** the system MAY also update write-through cache entries
- **AND** cache write failure SHALL NOT roll back or skip the database upsert

### Requirement: Project-level aggregation for management UI

When the project management UI needs a single status per project, the system MUST aggregate all `ClientOnlineStatus` rows for that `ProId` without collapsing them in storage. Device detail rows drive the device modal, not the project-level 未注册/在线/离线 badge.

#### Scenario: Aggregate online

- **WHEN** at least one row for the `ProId` has `IsConnected = true`
- **THEN** the project-level client badge SHALL be 在线

#### Scenario: Aggregate offline

- **WHEN** the `ProId` has one or more rows and every row has `IsConnected = false`
- **THEN** the project-level client badge SHALL be 离线

#### Scenario: Aggregate unregistered

- **WHEN** the `ProId` has no `ClientOnlineStatus` rows
- **THEN** the project-level client badge SHALL be 未注册

#### Scenario: Aggregate last online time

- **WHEN** the project table renders「最后在线时间」
- **THEN** the value SHALL be derived from the newest relevant timestamp among that `ProId`'s instance rows
- **AND** SHALL NOT use `GovProject.LastSyncTime`

#### Scenario: Device modal uses persisted details

- **WHEN** the user opens the project「设备」modal for a `ProId`
- **THEN** the UI SHALL render device cards from `GetClientDevicesAsync` backed by persisted device detail rows
- **AND** SHALL show status and last update time per device type (and per `ClientId` when multiple instances exist)

### Requirement: LastSeenAt refresh without dedicated heartbeat

The system SHALL expose a live-connection Touch path that renews last-seen and Redis live TTL for a `(ProId, ClientId)` instance, and MUST **recreate** a live online entry (`IsConnected = true`) when the live key is missing. Qualifying SignalR `UploadStatus` messages that carry usable `ProId` and `ClientId` MUST invoke this Touch path (not only on first Hub connection mapping). The system MUST NOT introduce a separate heartbeat Hub method. Optional minimum-interval throttle MAY limit how often last-seen timestamps advance, but MUST NOT skip renewing live key TTL on Touch. This capability does **not** require MaterialClient periodic presence republish.

#### Scenario: Status upload refreshes last-seen and live TTL

- **WHEN** an `UploadStatus` message includes known `ProId` and `ClientId`
- **AND** a live connection entry already exists
- **THEN** the system SHALL update that entry's last-seen subject to an optional throttle
- **AND** SHALL renew the live Redis TTL for that connection
- **AND** SHALL NOT require a new Hub method beyond `UploadStatus`

#### Scenario: Status upload recreates live online after TTL expiry

- **WHEN** an `UploadStatus` message includes known `ProId` and `ClientId`
- **AND** the live Redis connection key for that instance is missing (expired or never written)
- **AND** the SignalR connection may still be the same ConnectionId as before expiry
- **THEN** the system SHALL recreate a live online entry with `IsConnected = true`
- **AND** management client-list / project badge queries SHALL report the instance online after the upload

#### Scenario: Missing ClientId does not fall back to ProId-only upsert

- **WHEN** an `UploadStatus` that would register online or device detail lacks a usable `ClientId`
- **THEN** the system SHALL NOT upsert a ProId-only connection or device entry that would violate multi-instance uniqueness
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
