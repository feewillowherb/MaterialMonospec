## ADDED Requirements

### Requirement: Project list page rendering
`ProjectManagement.razor` SHALL render a paginated table of government projects with search and CRUD operations, consuming `IGovProjectAppService` via DI injection.

#### Scenario: Initial page load
- **WHEN** the user navigates to `/projects`
- **THEN** the page SHALL call `IGovProjectAppService.GetListAsync()` with default pagination (SkipCount=0, MaxResultCount=10)
- **AND** SHALL render a table with columns: 项目名称, 施工许可证号, 对接码, 同步状态, 最后同步时间, 操作

#### Scenario: Pagination
- **WHEN** the user clicks a page number
- **THEN** the page SHALL recalculate `SkipCount` and call `GetListAsync` with updated pagination
- **AND** SHALL display the current page number and total count

#### Scenario: Search filtering
- **WHEN** the user enters text in the search input and submits
- **THEN** the page SHALL call `GetListAsync` with the search text in `SearchText` parameter
- **AND** SHALL reset pagination to page 1

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

### Requirement: No GovProjectApiController dependency
`ProjectManagement.razor` SHALL NOT call any endpoint from `GovProjectApiController`. All data operations SHALL go through `IGovProjectAppService` (ABP convention routes).

#### Scenario: All operations use ApplicationService
- **WHEN** any CRUD operation is performed
- **THEN** the page SHALL call `IGovProjectAppService` methods directly via DI injection
- **AND** MUST NOT make HTTP requests to `/api/app/gov-project/*` endpoints
