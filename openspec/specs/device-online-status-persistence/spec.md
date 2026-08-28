# Device Online Status Persistence Specification

## Purpose

UrbanManagement 将桌面客户端实例在线态与设备详情当前态持久化到数据库，查询以库为准，支持同一 `ProId` 多 `ClientId`。

## Requirements

### Requirement: Client online status entity persistence

UrbanManagement MUST persist each desktop client instance's current online/offline connection state in the database via a `ClientOnlineStatus` entity that is unique by `(ProId, ClientId)`, registered on `UrbanManagementDbContext` with an EF Core migration. The schema MUST allow multiple rows per `ProId` so a future Urban V2 project can keep up to four concurrent machine instances online without a table redesign.

#### Scenario: Entity stored in DbContext

- **WHEN** the application data model is configured
- **THEN** `UrbanManagementDbContext` SHALL expose a `DbSet` for `ClientOnlineStatus`
- **AND** the entity SHALL include at least `ProId`, `ClientId`, `ProName`, `IsConnected`, `ConnectedAt`, `DisconnectedAt`, and `LastSeenAt`
- **AND** `(ProId, ClientId)` SHALL be unique
- **AND** `ProId` alone MUST NOT be a uniqueness constraint that would allow only one row per project

#### Scenario: Optional Slot column reserved for Urban V2

- **WHEN** the `ClientOnlineStatus` table is created
- **THEN** the entity MAY include a nullable `Slot` (`int?`) for future correlation with Urban V2 machine-code slots
- **AND** this change SHALL NOT require writing `Slot` on connect/disconnect
- **AND** `Slot` SHALL NOT be treated as the authorization source of truth

#### Scenario: Upsert on client instance online

- **WHEN** a MaterialClient SignalR connection maps a non-empty `ProId` and non-empty `ClientId` (online registration for that instance)
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

- **WHEN** UrbanManagement restarts after client instances have previously connected and disconnected
- **THEN** queries SHALL still return those `(ProId, ClientId)` rows with persisted state
- **AND** SHALL NOT treat the project as unregistered solely because distributed cache was empty

### Requirement: Device online detail current-state persistence

UrbanManagement MUST persist the latest online detail for each device type on each client instance via a `ClientDeviceOnlineStatus` entity (name may vary) that is unique by `(ProId, ClientId, DeviceType)`, registered on `UrbanManagementDbContext` with an EF Core migration. This is current-state storage for the project management device modal and `GetClientDevicesAsync`, not an append-only audit log.

#### Scenario: Device detail entity in DbContext

- **WHEN** the application data model is configured
- **THEN** `UrbanManagementDbContext` SHALL expose a `DbSet` for the device online detail entity
- **AND** each row SHALL include at least `ProId`, `ClientId`, `DeviceType`, `Status`, `LastUpdateTime`, and optional `AdditionalData`
- **AND** `(ProId, ClientId, DeviceType)` SHALL be unique

#### Scenario: Upsert on UploadStatus

- **WHEN** a valid `UploadStatus` message includes `ProId`, `ClientId`, `DeviceType`, and `Status`
- **THEN** the system SHALL upsert the matching device detail row with that status and timestamp
- **AND** SHALL NOT remove other device types or other `ClientId` rows under the same `ProId`

#### Scenario: Mark devices offline on instance disconnect

- **WHEN** a mapped `(ProId, ClientId)` SignalR connection disconnects
- **THEN** the system SHALL set `Status` to Offline (or equivalent) for all device detail rows of that `(ProId, ClientId)`
- **AND** SHALL update their `LastUpdateTime`
- **AND** SHALL NOT change device detail rows belonging to other `ClientId` values under the same `ProId`

#### Scenario: Device details survive restart

- **WHEN** UrbanManagement restarts after device statuses were persisted
- **THEN** `GetClientDevicesAsync` SHALL still return those current-state rows from the database
- **AND** SHALL NOT depend on `DeviceStatusCacheItem` being populated

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

The system SHALL refresh `LastSeenAt` on qualifying `UploadStatus` messages that carry `ProId` and `ClientId` when the matching `ClientOnlineStatus` row exists, without introducing a separate heartbeat Hub method in this capability. The refresh MUST support an optional minimum interval throttle.

#### Scenario: Status upload refreshes LastSeenAt for instance

- **WHEN** an `UploadStatus` message includes known `ProId` and `ClientId` and the instance row exists
- **THEN** the system SHALL update that row's `LastSeenAt` subject to an optional minimum interval throttle
- **AND** SHALL NOT require a new MaterialClient heartbeat protocol for this capability

#### Scenario: Missing ClientId does not fall back to ProId-only upsert

- **WHEN** an `UploadStatus` that would register online or device detail lacks a usable `ClientId`
- **THEN** the system SHALL NOT upsert a ProId-only connection or device row that would violate multi-instance uniqueness
- **AND** SHALL log a warning or error for diagnostics
