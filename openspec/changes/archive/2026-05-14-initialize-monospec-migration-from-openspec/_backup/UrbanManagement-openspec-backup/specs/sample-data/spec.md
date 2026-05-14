# Sample Data

## Purpose

Defines the sample data provider service that returns hardcoded data for development and demonstration, replacing the need for a live database during initial development.

## Requirements

### Requirement: ISampleDataProvider interface defines data access methods
The system SHALL define `ISampleDataProvider` interface in the Core project with methods: `GetPagedProjectsAsync(int page, int limit)`, `GetPagedSyncDataAsync(int page, int limit)`, `GetSyncLogsAsync(int syncDataId)`, and `GetDashboardStatsAsync()`.

#### Scenario: Interface is defined in Core project
- **WHEN** the Core project is compiled
- **THEN** `ISampleDataProvider` SHALL be resolvable from `UrbanManagement.Core.Services` namespace

### Requirement: SampleDataProvider returns hardcoded project data
`SampleDataProvider` SHALL implement `ISampleDataProvider` and return at least 3 sample `GovProject` records with varied data (different ProName, BuildLicenseNo, SyncStatus values).

#### Scenario: Project list returns multiple records
- **WHEN** `GetPagedProjectsAsync(1, 10)` is called
- **THEN** it SHALL return at least 3 sample GovProject records

#### Scenario: Pagination returns correct page
- **WHEN** `GetPagedProjectsAsync(1, 2)` is called
- **THEN** it SHALL return exactly 2 records and indicate total count is >= 3

### Requirement: SampleDataProvider returns hardcoded sync data
`SampleDataProvider` SHALL return at least 5 sample `GovSyncData` records with varied SyncType values (Pending, Success, Failed), associated ProName and BuildLicenseNo.

#### Scenario: Sync data includes various statuses
- **WHEN** `GetPagedSyncDataAsync(1, 10)` is called
- **THEN** the result SHALL contain records with SyncType values of 0, 1, and 2

#### Scenario: Sync data includes image references
- **WHEN** a sample sync data record is inspected
- **THEN** `SnapImages` SHALL contain at least one image path (can be placeholder)

### Requirement: SampleDataProvider returns hardcoded sync logs
`SampleDataProvider` SHALL return at least 2 sample `GovLog` records per sync data entry, with SyncTime, SyncNumber, SyncResult, and SyncMsg fields populated.

#### Scenario: Logs are returned for a sync data entry
- **WHEN** `GetSyncLogsAsync(1)` is called
- **THEN** it SHALL return at least 2 GovLog records with different SyncTime values

### Requirement: SampleDataProvider is registered as transient via ABP
`SampleDataProvider` SHALL implement `ITransientDependency` and use `[AutoConstructor]` for dependency injection, following the FluentSample service registration pattern.

#### Scenario: Service is injectable in controllers
- **WHEN** a controller constructor accepts `ISampleDataProvider`
- **THEN** ABP SHALL inject a `SampleDataProvider` instance

### Requirement: Sample data uses PascalCase property names
All DTO and entity objects returned by `SampleDataProvider` SHALL use PascalCase property names. JSON serialization from controllers SHALL use camelCase to match the original AJAX response format expected by LayUI views.

#### Scenario: JSON response uses camelCase for frontend compatibility
- **WHEN** a controller returns sample data as JSON
- **THEN** property names SHALL be camelCase (e.g., `proName`, `buildLicenseNo`) matching the LayUI table column field names

### Requirement: 控制器 API 端点返回 mock 数据供前端调用
所有前端 AJAX 请求 SHALL 调用现有控制器 API 端点，控制器内部通过 `ISampleDataProvider` 返回 mock 数据。无需前端 mock 拦截层。

#### Scenario: 项目列表 API 返回 mock 数据
- **WHEN** 前端发送 GET 请求到 `/Project/PageList?page=1&limit=10`
- **THEN** 控制器 SHALL 返回 JSON 响应 `{ success: true, msg: "Success", count: N, data: [...] }`，data 数组包含 ProName、BuildLicenseNo、FdBuildLicenseNo、SyncStatus、LastSyncTime 等字段

#### Scenario: 同步数据列表 API 返回 mock 数据
- **WHEN** 前端发送 GET 请求到 `/SyncInfo/PageList?page=1&limit=10`
- **THEN** 控制器 SHALL 返回 JSON 响应包含 CarNo、GoodsWeight、SnapTime、ProName、BuildLicenseNo、SyncType、SyncNumber、SyncTime 等字段

#### Scenario: 同步日志 API 返回 mock 数据
- **WHEN** 前端发送 GET 请求到 `/SyncInfo/LogList?id=1`
- **THEN** 控制器 SHALL 返回 JSON 响应包含 SyncTime、SyncNumber、SyncSource、SyncResult、SyncMsg 等字段

#### Scenario: 项目添加 API 返回 mock 成功响应
- **WHEN** 前端发送 POST 请求到 `/Project/Add` 包含表单数据
- **THEN** 控制器 SHALL 返回 `{ success: true, msg: "Mock: Add succeeded" }`

#### Scenario: 项目删除 API 返回 mock 成功响应
- **WHEN** 前端发送 POST 请求到 `/Project/Del` 包含 proId
- **THEN** 控制器 SHALL 返回 `{ success: true, msg: "Mock: Delete succeeded" }`

#### Scenario: 项目状态切换 API 返回 mock 成功响应
- **WHEN** 前端发送 POST 请求到 `/Project/SetStatus` 包含 proId
- **THEN** 控制器 SHALL 返回 `{ success: true, msg: "Mock: Status toggled" }`

### Requirement: 仪表盘数据使用硬编码 mock 值
`Views/MainPage/Index.cshtml` 仪表盘页面 SHALL 使用硬编码的 mock 数据展示统计信息，不通过 API 获取。

#### Scenario: 仪表盘统计数据展示
- **WHEN** 仪表盘页面加载
- **THEN** 四个统计卡片 SHALL 显示硬编码数值：今日数、出勤数、在岗数、在册数

#### Scenario: 仪表盘 ECharts 图表展示
- **WHEN** 仪表盘页面加载
- **THEN** ECharts 图表 SHALL 使用硬编码的时序数据渲染折线图

#### Scenario: 仪表盘最新动态展示
- **WHEN** 仪表盘页面加载
- **THEN** 最新动态列表 SHALL 显示硬编码的工人进出记录（中文姓名、时间描述）
