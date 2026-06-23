# Blazor Weighing Record

## Purpose

定义 UrbanManagement Blazor 应用的称重记录页面，包括称重记录列表、搜索、分页、数据质量显示、同步状态显示、审批操作和可搜索项目下拉选择。项目名称输入已替换为 SearchableSelectable 下拉组件，支持 URL 参数预选项目。该页面通过 `IUrbanWeighingRecordAppService` 与 ABP ApplicationService 交互，项目列表通过 `IGovProjectAppService` 获取。
## Requirements
### Requirement: Weighing record list page rendering

`WeighingRecord.razor` SHALL render a paginated table of weighing records, consuming `IUrbanWeighingRecordAppService` via DI injection.

#### Scenario: Initial page load

- **WHEN** the user navigates to `/weighing`
- **THEN** the page SHALL call `IUrbanWeighingRecordAppService.GetListAsync()` with default pagination
- **AND** SHALL render a table with columns: 车牌号, 重量(kg), 称重时间, 项目名, 对接码, 数据质量, 异常原因, 同步状态, 同步时间, 操作

#### Scenario: Pagination

- **WHEN** the user selects a different page size or page number
- **THEN** the page SHALL recalculate `SkipCount` and call `GetListAsync` with updated parameters

#### Scenario: Search by plate number and project name

- **WHEN** the user enters search text in the plate number and/or project name inputs
- **THEN** the page SHALL call `GetListAsync` with the search criteria
- **AND** SHALL reset to page 1

### Requirement: Weighing record data quality display
`WeighingRecord.razor` SHALL display data quality (anomaly) status for each record.

#### Scenario: Anomaly status badge
- **WHEN** a record has `IsAnomaly = true`
- **THEN** the data quality column SHALL display a red "异常" badge
- **WHEN** a record has `IsAnomaly = false`
- **THEN** the data quality column SHALL display a green "正常" badge

### Requirement: Weighing record sync status display
`WeighingRecord.razor` SHALL display sync status for each record.

#### Scenario: Sync type badge
- **WHEN** a record has `SyncType = 2`
- **THEN** the sync status column SHALL display "同步失败" in red
- **WHEN** a record has `SyncType = 1`
- **THEN** the sync status column SHALL display "同步成功" in green
- **WHEN** a record has `SyncType = 0`
- **THEN** the sync status column SHALL display "待同步" in cyan

### Requirement: SearchableSelect project name dropdown
WeighingRecord.razor SHALL replace the plain text input for project name with a SearchableSelect dropdown. See `searchable-project-select` capability for full specification.

#### Scenario: Project name dropdown replaces text input
- **WHEN** WeighingRecord page renders
- **THEN** the project name search field SHALL be a SearchableSelect dropdown component with search filtering and keyboard navigation

#### Scenario: Pre-select project from URL parameter
- **WHEN** the page loads with `proName` query parameter
- **THEN** the SearchableSelect SHALL pre-select the matching project and trigger filtered search

### Requirement: No Layui dependency
`WeighingRecord.razor` SHALL NOT load or use the Layui JavaScript library. All table rendering, pagination, and dialog functionality SHALL use pure Blazor components.

#### Scenario: No Layui CDN reference
- **WHEN** the weighing record page renders
- **THEN** the page MUST NOT reference `layui.js` or `layui.css` from any CDN
- **AND** MUST NOT call any `layui.*` JavaScript API

### Requirement: Weighing record photo view operation

`WeighingRecord.razor` SHALL provide a「查看照片」button in the 操作 column for each record row. See `urban-weighing-photo-view` capability for dialog behavior.

#### Scenario: Photo view button visible on each row

- **WHEN** the weighing record table renders with one or more rows
- **THEN** each row SHALL include a「查看照片」button in the 操作 column

#### Scenario: Photo view loads attachments by record id

- **WHEN** the user clicks「查看照片」
- **THEN** the page SHALL call `GetApprovalAttachmentsAsync` with that row's record `Id`
- **AND** SHALL display Lrp and UrbanPhoto images per `urban-weighing-photo-view` requirements

