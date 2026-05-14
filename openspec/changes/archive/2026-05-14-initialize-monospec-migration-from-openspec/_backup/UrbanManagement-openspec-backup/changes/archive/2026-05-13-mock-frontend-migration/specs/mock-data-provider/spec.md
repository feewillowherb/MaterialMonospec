## ADDED Requirements

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
