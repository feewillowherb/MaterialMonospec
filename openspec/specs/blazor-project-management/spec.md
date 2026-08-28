# Blazor Project Management

## Purpose

定义 UrbanManagement Blazor 应用的项目管理页面，包括项目列表、搜索、分页、CRUD 操作、客户端连接状态显示、设备详情查看、称重记录导航和实时 SignalR 更新。该页面通过 `IGovProjectAppService` 与 ABP ApplicationService 交互，不使用任何 MVC 控制器。客户端状态和设备详情通过 `IDeviceStatusAppService` 获取。

## Requirements

### Requirement: Project list page rendering
`ProjectManagement.razor` SHALL render a paginated table of government projects with search and CRUD operations, consuming `IGovProjectAppService` via DI injection.

#### Scenario: Initial page load
- **WHEN** the user navigates to `/projects`
- **THEN** the page SHALL call `IGovProjectAppService.GetListAsync()` with default pagination (SkipCount=0, MaxResultCount=10)
- **AND** SHALL render a table including columns: 项目名称, 项目地址, 施工单位, 对接码, 授权过期时间, 客户端, 启用同步, 最后在线时间, 操作
- **AND** SHALL NOT label the online-time column as「最后同步时间」when binding client online persistence fields

#### Scenario: Pagination
- **WHEN** the user clicks a page number
- **THEN** the page SHALL recalculate `SkipCount` and call `GetListAsync` with updated pagination
- **AND** SHALL display the current page number and total count

#### Scenario: Search filtering
- **WHEN** the user enters text in the search input and submits
- **THEN** the page SHALL call `GetListAsync` with the search text in `SearchText` parameter
- **AND** SHALL reset pagination to page 1

### Requirement: Last online time column binding
`ProjectManagement.razor` SHALL bind the「最后在线时间」column to persisted client connection timestamps from `GetClientListAsync` (merged by ProId), not `project.LastSyncTime`.

#### Scenario: Column uses client connection timestamps
- **WHEN** a project row is rendered and a matching client connection DTO exists
- **THEN** the cell SHALL display `ConnectedAt` when online, otherwise `DisconnectedAt` or `LastSeenAt`
- **AND** SHALL NOT display `GovProject.LastSyncTime` for this column

### Requirement: Device modal binds persisted online details
`ProjectManagement.razor` device modal SHALL load and display device online details from `GetClientDevicesAsync` backed by persisted current-state data.

#### Scenario: Device button opens DB-backed details
- **WHEN** the user clicks「设备」on a project row
- **THEN** the page SHALL call `GetClientDevicesAsync` for that project
- **AND** SHALL render device status and last update time from the result
- **AND** when multiple client instances exist, SHALL keep `ClientId` distinguishable in the presented data

### Requirement: Project create operation
`ProjectManagement.razor` SHALL allow creating a new project via a modal dialog.

#### Scenario: Create project dialog
- **WHEN** the user clicks the "添加" button
- **THEN** a modal dialog SHALL appear with form fields: 项目名称 (required), 对接码 (required), 施工许可证号 (optional)
- **AND** clicking "保存" SHALL call `IGovProjectAppService.CreateAsync()` with the form data
- **AND** on success, the table SHALL refresh and the dialog SHALL close

### Requirement: Project edit operation
`ProjectManagement.razor` SHALL allow editing an existing project via a modal dialog.

#### Scenario: Edit project dialog
- **WHEN** the user clicks the "编辑" button on a table row
- **THEN** a modal dialog SHALL appear pre-populated with the project data (loaded via `IGovProjectAppService.GetAsync(id)`)
- **AND** clicking "保存" SHALL call `IGovProjectAppService.UpdateAsync()` with the modified data
- **AND** on success, the table SHALL refresh and the dialog SHALL close

### Requirement: Project delete operation
`ProjectManagement.razor` SHALL allow soft-deleting a project.

#### Scenario: Delete with confirmation
- **WHEN** the user clicks the "删除" button on a table row
- **THEN** a confirmation dialog SHALL appear
- **AND** on confirmation, SHALL call `IGovProjectAppService.DeleteAsync()` with the project ID
- **AND** on success, the table SHALL refresh

### Requirement: Project sync status toggle
`ProjectManagement.razor` SHALL allow toggling the sync status of a project.

#### Scenario: Toggle sync status
- **WHEN** the user clicks the sync status badge
- **THEN** the page SHALL call `IGovProjectAppService.SetSyncStatusAsync()` with the inverted status
- **AND** on success, the table SHALL refresh

### Requirement: Client connection status column
ProjectManagement.razor SHALL display each project's client connection status by merging data from `IDeviceStatusAppService.GetClientListAsync`. See `project-client-merge` capability for full specification.

#### Scenario: Client status column rendering
- **WHEN** ProjectManagement page loads
- **THEN** the project table SHALL include a "客户端" column showing connection status badges (在线/离线/未注册)

### Requirement: Device detail modal
ProjectManagement.razor SHALL provide a "设备" button on each project row to view device details via modal. See `project-client-merge` capability for full specification.

#### Scenario: Device modal opens from project row
- **WHEN** user clicks "设备" on a project row
- **THEN** a modal SHALL display device cards reusing `IDeviceStatusAppService.GetClientDevicesAsync`

### Requirement: Weighing record navigation from project row
ProjectManagement.razor SHALL provide a "称重" button on each project row that navigates to WeighingRecord with pre-selected project. See `project-weighing-link` capability for full specification.

#### Scenario: Weighing button navigates with project name
- **WHEN** user clicks "称重" on a project row
- **THEN** the system SHALL navigate to `/weighing?proName=<project name>`

### Requirement: Real-time client status via SignalR
ProjectManagement.razor SHALL subscribe to SignalR for real-time client status updates with polling fallback. See `project-client-merge` capability for full specification.

#### Scenario: SignalR client status updates
- **WHEN** a `ClientConnectionUpdate` event fires
- **THEN** the corresponding project row's client status badge SHALL update in real-time

### Requirement: No GovProjectApiController dependency
`ProjectManagement.razor` SHALL NOT call any endpoint from `GovProjectApiController`. All data operations SHALL go through `IGovProjectAppService` (ABP convention routes).

#### Scenario: All operations use ApplicationService
- **WHEN** any CRUD operation is performed
- **THEN** the page SHALL call `IGovProjectAppService` methods directly via DI injection
- **AND** MUST NOT make HTTP requests to `/api/app/gov-project/*` endpoints
