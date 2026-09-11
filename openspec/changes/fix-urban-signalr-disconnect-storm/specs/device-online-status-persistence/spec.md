## MODIFIED Requirements

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
- **AND** the offline upsert MUST remain best-effort even when the hub connection abort token is already canceled (persistence MUST use an independent cancellation scope)

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
