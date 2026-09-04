## ADDED Requirements

### Requirement: Project management is the application home
`ProjectManagement.razor` SHALL be the application home page at `/`, and SHALL remain reachable at `/projects`.

#### Scenario: Root route shows project management
- **WHEN** the user navigates to `/`
- **THEN** the system SHALL render the project management page (not a dashboard)
- **AND** MUST NOT render `Dashboard.razor` content

#### Scenario: Legacy projects route still works
- **WHEN** the user navigates to `/projects`
- **THEN** the system SHALL render the same project management page as `/`

### Requirement: Client connection status filter
`ProjectManagement.razor` SHALL provide a filter for project-level client connection status with options: 全部, 在线, 离线, 未注册. The filter semantics MUST match the existing client status badges (online / offline / unregistered via `ProjectClientConnectionAggregate`).

#### Scenario: Filter to online projects
- **WHEN** the user selects the「在线」filter and the list reloads
- **THEN** the page SHALL call `IGovProjectAppService.GetListAsync` with a client-connection status filter for online
- **AND** every rendered row's client status badge SHALL be「在线」
- **AND** pagination SHALL reset to page 1
- **AND** `TotalCount` SHALL reflect only matching projects

#### Scenario: Filter to offline projects
- **WHEN** the user selects the「离线」filter
- **THEN** the list SHALL include only projects whose aggregated client status is offline
- **AND** SHALL exclude online and unregistered projects

#### Scenario: Filter to unregistered projects
- **WHEN** the user selects the「未注册」filter
- **THEN** the list SHALL include only projects with no registered client connection rows

#### Scenario: Filter combines with search text
- **WHEN** the user has non-empty search text and a non-全部 status filter
- **THEN** `GetListAsync` SHALL apply both `SearchText` and the status filter
- **AND** the returned page SHALL satisfy both constraints

#### Scenario: Clear filter to all
- **WHEN** the user selects「全部」
- **THEN** `GetListAsync` SHALL be called without a restrictive status filter (or with an explicit all/null filter)
- **AND** the list MAY include online, offline, and unregistered projects

### Requirement: Default sort by client connection status
`IGovProjectAppService.GetListAsync` SHALL default-sort projects by client connection status priority: online first, then offline, then unregistered, unless a caller supplies an overriding sort that the implementation honors for that call.

#### Scenario: Default list order prefers online
- **WHEN** the user opens project management with default filter（全部）and default paging
- **THEN** all online projects in the result set SHALL appear before offline projects
- **AND** all offline projects SHALL appear before unregistered projects

#### Scenario: Same-status secondary order is stable
- **WHEN** multiple projects share the same connection status
- **THEN** those projects SHALL keep a deterministic secondary order (e.g. `CreationTime` descending)

## MODIFIED Requirements

### Requirement: Project list page rendering

`ProjectManagement.razor` SHALL render a paginated table of government projects with search, client-connection status filter, and CRUD operations, consuming `IGovProjectAppService` via DI injection.

#### Scenario: Initial page load

- **WHEN** the user navigates to `/` or `/projects`
- **THEN** the page SHALL call `IGovProjectAppService.GetListAsync()` with default pagination (SkipCount=0, MaxResultCount=10) and default status sort (online → offline → unregistered)
- **AND** SHALL render a table including columns: 项目名称, 项目地址, 施工单位, 对接码, 授权过期时间, 客户端, 启用同步, 最后在线时间, 操作
- **AND** the「启用同步」control SHALL bind to `GovProjectDto.IsSyncEnabled` (not `EnableSync`)
- **AND** SHALL NOT label the online-time column as「最后同步时间」when binding client online persistence fields

#### Scenario: Pagination

- **WHEN** the user clicks a page number
- **THEN** the page SHALL recalculate `SkipCount` and call `GetListAsync` with updated pagination and the current search/status filter
- **AND** SHALL display the current page number and total count

#### Scenario: Search filtering

- **WHEN** the user enters text in the search input and submits
- **THEN** the page SHALL call `GetListAsync` with the search text in `SearchText` parameter and the current status filter
- **AND** SHALL reset pagination to page 1
