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
`/clients`, `/clients/{proId}`, and `/device-status` routes SHALL be removed along with ClientList.razor, ClientDetail.razor, and DeviceStatus.razor files. The sidebar navigation SHALL be reduced to 3 items: 仪表盘, 项目管理, 称重记录.

#### Scenario: Navigation no longer shows removed pages
- **WHEN** user views the sidebar navigation
- **THEN** "客户端管理" and "设备状态" menu items SHALL NOT appear

#### Scenario: Direct URL access to removed pages
- **WHEN** user navigates directly to `/clients` or `/device-status`
- **THEN** the system SHALL redirect to `/projects`
