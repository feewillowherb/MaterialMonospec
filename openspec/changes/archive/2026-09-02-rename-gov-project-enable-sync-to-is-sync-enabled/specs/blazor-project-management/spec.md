## MODIFIED Requirements

### Requirement: Project list page rendering

`ProjectManagement.razor` SHALL render a paginated table of government projects with search and CRUD operations, consuming `IGovProjectAppService` via DI injection.

#### Scenario: Initial page load

- **WHEN** the user navigates to `/projects`
- **THEN** the page SHALL call `IGovProjectAppService.GetListAsync()` with default pagination (SkipCount=0, MaxResultCount=10)
- **AND** SHALL render a table including columns: 项目名称, 项目地址, 施工单位, 对接码, 授权过期时间, 客户端, 启用同步, 最后在线时间, 操作
- **AND** the「启用同步」control SHALL bind to `GovProjectDto.IsSyncEnabled` (not `EnableSync`)
- **AND** SHALL NOT label the online-time column as「最后同步时间」when binding client online persistence fields

#### Scenario: Pagination

- **WHEN** the user clicks a page number
- **THEN** the page SHALL recalculate `SkipCount` and call `GetListAsync` with updated pagination
- **AND** SHALL display the current page number and total count

#### Scenario: Search filtering

- **WHEN** the user enters text in the search input and submits
- **THEN** the page SHALL call `GetListAsync` with the search text in `SearchText` parameter
- **AND** SHALL reset pagination to page 1

### Requirement: Project sync status toggle

`ProjectManagement.razor` SHALL allow toggling whether government sync is enabled for a project.

#### Scenario: Toggle IsSyncEnabled

- **WHEN** the user toggles the「启用同步」switch on a project row
- **THEN** the page SHALL call `IGovProjectAppService.SetIsSyncEnabledAsync()` with the target `IsSyncEnabled` value
- **AND** on success, the table SHALL refresh
- **AND** MUST NOT call `SetEnableSyncAsync` or send an `enableSync` payload field
