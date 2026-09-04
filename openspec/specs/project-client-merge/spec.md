# Project Client Merge

## Purpose

定义将客户端连接状态和设备详情功能合并到项目管理页面的规范。移除独立的客户端管理和设备状态页面，将其实时状态更新、设备详情查看功能整合到 ProjectManagement.razor 中。

## Requirements

### Requirement: Project table displays client connection status
ProjectManagement.razor SHALL display each project's client connection status (online/offline) directly in the project list table, merging data from `IGovProjectAppService.GetListAsync` and `IDeviceStatusAppService.GetClientListAsync`.

#### Scenario: Project with online client
- **WHEN** ProjectManagement page loads and a project has a connected client
- **THEN** the project row SHALL show a green "在线" badge in the client status column

#### Scenario: Project with offline client
- **WHEN** ProjectManagement page loads and a project's client is disconnected
- **THEN** the project row SHALL show a red "离线" badge in the client status column

#### Scenario: Project without registered client
- **WHEN** ProjectManagement page loads and no client has registered for a given project
- **THEN** the project row SHALL show a gray "未注册" badge in the client status column

### Requirement: Device detail modal on project row
Each project row SHALL provide a "设备" button that opens a modal dialog showing the client's device details, reusing `IDeviceStatusAppService.GetClientDevicesAsync`.

#### Scenario: View device details for online project
- **WHEN** user clicks the "设备" button on a project row
- **THEN** a modal SHALL display device cards (Scale, Camera, LPR, Sound, Printer) with status and last update time, identical to current ClientDetail.razor layout

#### Scenario: Device detail modal for project without devices
- **WHEN** user clicks "设备" on a project with no reported device data
- **THEN** the modal SHALL display "暂无设备数据" empty state

### Requirement: Real-time connection status updates via SignalR
ProjectManagement.razor SHALL subscribe to SignalR `ClientConnectionUpdate` events to refresh client connection status in real-time, with 30-second fallback polling when SignalR is disconnected.

#### Scenario: Client connects while page is open
- **WHEN** a client connects and the `ClientConnectionUpdate` SignalR event fires
- **THEN** the corresponding project row's client status badge SHALL update to "在线" without full page reload

#### Scenario: SignalR disconnected fallback
- **WHEN** SignalR connection is lost for more than 30 seconds
- **THEN** the system SHALL fall back to polling `GetClientListAsync` every 30 seconds to refresh status

### Requirement: Remove standalone client and device pages
`/clients`, `/clients/{proId}`, and `/device-status` routes SHALL be removed along with ClientList.razor, ClientDetail.razor, and DeviceStatus.razor files. The sidebar primary navigation SHALL treat 项目管理 as the home entry at `/` and MUST NOT include 仪表盘.

#### Scenario: Navigation no longer shows removed pages
- **WHEN** user views the sidebar navigation
- **THEN** "客户端管理" and "设备状态" menu items SHALL NOT appear
- **AND** "仪表盘" menu item SHALL NOT appear
- **AND** "项目管理" SHALL be available as the home route `/`

#### Scenario: Direct URL access to removed pages
- **WHEN** user navigates directly to `/clients` or `/device-status`
- **THEN** the system SHALL redirect to project management home (`/` or `/projects`)

### Requirement: Status filter uses project-client merge semantics
Project list status filtering SHALL use the same online / offline / unregistered rules as the project table client status column.

#### Scenario: Online filter matches green badge rule
- **WHEN** a project has at least one connected client instance for its `ProId`
- **THEN** it SHALL be included when the online filter is selected
- **AND** SHALL be excluded from offline and unregistered filters

#### Scenario: Unregistered filter matches gray badge rule
- **WHEN** a project has no `ClientOnlineStatus` / client connection rows
- **THEN** it SHALL be included when the unregistered filter is selected
- **AND** SHALL show the gray「未注册」badge when rendered

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
