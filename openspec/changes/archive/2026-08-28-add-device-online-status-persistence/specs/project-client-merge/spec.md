## ADDED Requirements

### Requirement: Project table displays last online time

ProjectManagement.razor SHALL display a「最后在线时间」column sourced from persisted multi-instance client online status aggregated by `ProId`, not from `GovProject.LastSyncTime`.

#### Scenario: Online project shows newest instance timestamp

- **WHEN** the project has at least one client instance with `IsConnected = true`
- **THEN** the row SHALL show an aggregated last-online timestamp derived from instance rows, formatted as `yyyy-MM-dd HH:mm:ss`

#### Scenario: Offline project shows newest disconnect/seen time

- **WHEN** the project has instance rows and all are offline
- **THEN** the row SHALL show the newest `DisconnectedAt` or `LastSeenAt` among those instances

#### Scenario: Unregistered client shows dash

- **WHEN** the project has no `ClientOnlineStatus` rows (未注册)
- **THEN** the「最后在线时间」column SHALL show `-`

#### Scenario: Must not bind LastSyncTime for online column

- **WHEN** the project list renders the last-online column
- **THEN** the page SHALL NOT use `GovProject.LastSyncTime` as the value for that column

### Requirement: Device modal shows persisted online details

The project row「设备」modal MUST display device online details loaded via `GetClientDevicesAsync`, backed by persisted current-state rows (not cache-only).

#### Scenario: Modal renders status cards from DB-backed API

- **WHEN** user clicks「设备」on a project row
- **THEN** the modal SHALL call `GetClientDevicesAsync` for that project's `ProId`
- **AND** SHALL render device type cards with status and last update time from the API result

#### Scenario: Modal empty when no persisted device rows

- **WHEN** `GetClientDevicesAsync` returns an empty list
- **THEN** the modal SHALL show the empty state（如「暂无设备数据」）

#### Scenario: Multi-instance device details remain distinguishable

- **WHEN** multiple `ClientId` instances have device detail rows under the same `ProId`
- **THEN** the modal data SHALL retain `ClientId` (or equivalent grouping) so instances are not silently merged into one ambiguous card set
