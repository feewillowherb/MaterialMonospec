## MODIFIED Requirements

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

## ADDED Requirements

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
