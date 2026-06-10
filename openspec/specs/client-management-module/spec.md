# Client Management Module

## Purpose

Provides the client management module for the UrbanManagement system, replacing the previous device management module. This module focuses on managing clients (ProId/ClientId) rather than individual devices, providing a list view of all clients and their connection status, with drill-down capability to view device details for each client.

## Requirements

### Requirement: ClientManagementController 路由

UrbanManagement.App MUST 提供 `ClientManagementController` 控制器，取代原有的 `DeviceManagementController`，作为客户端管理模块的入口控制器。

#### Scenario: 列表页路由

- **WHEN** 浏览器请求 `/ClientManagement/Index`
- **THEN** `ClientManagementController.Index()` SHALL 返回客户端连接状态列表视图
- **AND** 原有 `DeviceManagementController` MUST NOT 存在

#### Scenario: 详情页路由

- **WHEN** 浏览器请求 `/ClientManagement/Detail?id={proId}`
- **THEN** `ClientManagementController.Detail(string id)` SHALL 返回客户端设备在线详情视图
- **AND** `id` 参数为可选，为空时 SHALL 显示错误提示

### Requirement: 导航菜单更名

UrbanManagement 的 admin 布局侧边栏菜单项 MUST 将"设备管理"更改为"客户端管理"，路由指向新的控制器。

#### Scenario: 侧边栏菜单项更新

- **WHEN** 用户查看 Home/Index.cshtml 中的侧边栏导航
- **THEN** 原"设备管理"菜单项 SHALL 更新为"客户端管理"
- **AND** 菜单项的 `data-url` SHALL 指向 `/ClientManagement/Index`
- **AND** 菜单项的 `data-title` SHALL 为"客户端管理"

#### Scenario: 旧菜单项不存在

- **WHEN** Home/Index.cshtml 渲染完成
- **THEN** 页面中 MUST NOT 包含指向 `/DeviceManagement/Index` 的导航链接

### Requirement: 视图目录迁移

UrbanManagement.App MUST 将 `Views/DeviceManagement/` 目录重命名为 `Views/ClientManagement/`，并更新所有视图文件中的文案。

#### Scenario: 视图目录结构

- **WHEN** 构建完成后检查 Views 目录
- **THEN** `Views/DeviceManagement/` 目录 MUST NOT 存在
- **AND** `Views/ClientManagement/Index.cshtml` MUST 存在
- **AND** `Views/ClientManagement/Detail.cshtml` MUST 存在

#### Scenario: 列表页标题更新

- **WHEN** 浏览器加载 `/ClientManagement/Index` 页面
- **THEN** 页面 `<title>` SHALL 为"客户端管理"
- **AND** 页面标题 SHALL 为"客户端列表"

### Requirement: 客户端列表页（连接状态展示）

客户端管理列表页 MUST 以客户端（ProId/ClientId）为行单位展示，每行对应一个客户端，显示该客户端的 SignalR 长连接状态信息。

#### Scenario: 列表页基本结构

- **WHEN** 客户端列表页加载完成
- **THEN** 页面 SHALL 显示一个表格，每行对应一个客户端（ProId）
- **AND** 表格列 SHALL 包含：客户端名称、连接状态、连接时间、断开时间、操作

#### Scenario: 客户端名称显示

- **WHEN** 客户端有 ProName
- **THEN** 客户端名称列 SHALL 显示 ProName
- **WHEN** 客户端无 ProName
- **THEN** 客户端名称列 SHALL 显示 ClientId

#### Scenario: 连接状态显示

- **WHEN** 客户端当前 SignalR 长连接处于连接状态
- **THEN** 连接状态列 SHALL 显示 🟢 "在线"

- **WHEN** 客户端当前 SignalR 长连接处于断开状态
- **THEN** 连接状态列 SHALL 显示 🔴 "离线"

#### Scenario: 连接时间显示

- **WHEN** 客户端有连接记录
- **THEN** 连接时间列 SHALL 显示该客户端最后一次建立连接的时间（OnConnectedAsync 时间）
- **AND** 格式为 `yyyy-MM-dd HH:mm:ss`

#### Scenario: 断开时间显示

- **WHEN** 客户端当前 SignalR 长连接处于连接状态
- **THEN** 断开时间列 SHALL 显示 "-"

- **WHEN** 客户端当前 SignalR 长连接处于断开状态
- **THEN** 断开时间列 SHALL 显示该客户端最后一次断开连接的时间（OnDisconnectedAsync 时间）
- **AND** 格式为 `yyyy-MM-dd HH:mm:ss`

#### Scenario: 查看详情操作

- **WHEN** 用户点击某行的"查看详情"
- **THEN** 页面 SHALL 跳转至 `/ClientManagement/Detail?id={proId}`
- **AND** 使用该行数据的 ProId 作为 id 参数

### Requirement: 客户端列表页数据加载

列表页 MUST 通过 HTTP API 获取初始数据，同时通过浏览器端 SignalR 接收实时连接状态更新。

#### Scenario: 初始数据加载

- **WHEN** 列表页加载
- **THEN** 页面 SHALL 调用 `GET /api/app/device-status/client-list`
- **AND** SHALL 使用返回的 ClientConnectionDto 列表渲染表格行

#### Scenario: SignalR 实时更新

- **WHEN** SignalR 收到 `ClientConnectionUpdate` 事件
- **THEN** 列表页 SHALL 更新对应该客户端行的连接状态、连接时间和断开时间
- **AND** 若该 ProId 的行不存在 SHALL 新增一行

#### Scenario: 连接状态指示器

- **WHEN** 列表页 SignalR 连接状态发生变化
- **THEN** 页面 SHALL 显示浏览器端连接状态指示器（实时更新 / 连接断开 / 重连中）

#### Scenario: 浏览器 SignalR 断开时降级轮询

- **WHEN** 浏览器与 UrbanManagement 之间的 SignalR 连接断开
- **THEN** 列表页 SHALL 启动 30 秒间隔的轮询调用 `GET /api/app/device-status/client-list` 作为降级方案
- **AND** SignalR 重连成功后 SHALL 停止轮询

### Requirement: GetClientListAsync API 方法

DeviceStatusAppService MUST 新增 `GetClientListAsync` 方法，从分布式缓存中读取所有客户端的连接状态记录。

#### Scenario: 读取客户端连接列表

- **WHEN** 调用 `GetClientListAsync()` 方法
- **THEN** 服务 SHALL 从分布式缓存连接注册表获取所有 ProId
- **AND** SHALL 读取每个 ProId 的连接记录（`client_connection:{proId}`）
- **AND** SHALL 返回 ClientConnectionDto 列表

#### Scenario: API 路由注册

- **WHEN** UrbanManagement 应用启动
- **THEN** ABP 自动路由 SHALL 将 `GetClientListAsync` 暴露为 `GET /api/app/device-status/client-list`

#### Scenario: 分页支持

- **WHEN** 调用 `GetClientListAsync` 接口
- **THEN** 接口 SHALL 支持 `skipCount` 和 `maxResultCount` 分页参数
- **AND** SHALL 支持 `keyword` 参数用于模糊搜索 ProName
- **AND** SHALL 返回 `PagedResultDto<ClientConnectionDto>` 包含 `items` 和 `totalCount`

### Requirement: Hub 连接生命周期缓存

DeviceStatusHub MUST 在客户端连接和断开时将连接元数据写入分布式缓存，并广播连接状态变更事件至浏览器端。

#### Scenario: 客户端连接时缓存连接元数据

- **WHEN** MaterialClient 连接至 DeviceStatusHub（OnConnectedAsync）
- **THEN** Hub SHALL 从连接上下文中提取 ProId（通过最近上报的 DeviceStatusMessage 或已知的 ClientId-ProId 映射）
- **AND** SHALL 将连接元数据写入缓存 `client_connection:{proId}`，包含 IsConnected=true、ConnectedAt=当前时间
- **AND** SHALL 将 ProId 注册到连接注册表缓存 `__connection_registry__`

#### Scenario: 客户端断开时更新断开时间

- **WHEN** MaterialClient 断开 DeviceStatusHub 连接（OnDisconnectedAsync）
- **THEN** Hub SHALL 更新缓存 `client_connection:{proId}` 中的 IsConnected=false、DisconnectedAt=当前时间
- **AND** SHALL 保留 ConnectedAt 不变（记录的是最近一次连接时间）

#### Scenario: 广播连接状态变更

- **WHEN** Hub 完成 OnConnectedAsync 或 OnDisconnectedAsync 中的缓存更新
- **THEN** Hub SHALL 向 `client_connection` SignalR 组广播 `ClientConnectionUpdate` 事件
- **AND** 事件载荷 SHALL 包含 ProId、ProName、IsConnected、ConnectedAt、DisconnectedAt
