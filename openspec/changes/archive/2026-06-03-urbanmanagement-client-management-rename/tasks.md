## 1. 控制器重命名与视图目录迁移

- [x] 1.1 将 `Controllers/DeviceManagementController.cs` 重命名为 `Controllers/ClientManagementController.cs`，更新类名、命名空间注释和 XML 文档注释中的"device"相关措辞
- [x] 1.2 在 `ClientManagementController` 中新增 `Detail(string? id)` action 方法，返回 Detail 视图；当 id 为空时返回错误提示视图或重定向回列表
- [x] 1.3 将 `Views/DeviceManagement/` 目录重命名为 `Views/ClientManagement/`
- [x] 1.4 更新 `Views/ClientManagement/Index.cshtml`：页面 `<title>` 改为"客户端管理"，标题改为"客户端列表"
- [x] 1.5 删除 `Views/DeviceManagement/` 目录（如重命名后仍存在）

## 2. 导航菜单更新

- [x] 2.1 更新 `Views/Home/Index.cshtml` 侧边栏菜单项：`data-title` 从"设备管理"改为"客户端管理"，`data-url` 从 `/DeviceManagement/Index` 改为 `/ClientManagement/Index`
- [x] 2.2 更新 `Views/Shared/_Layout.cshtml` 导航栏：链接文本从"Device Management"改为"Client Management"，路由从 `DeviceManagement` 改为 `ClientManagement`

## 3. Hub 连接生命周期缓存

- [x] 3.1 在 `IDeviceStatusService` 接口中新增连接生命周期缓存方法签名
- [x] 3.2 在 `DeviceStatusService` 中实现：`OnConnectedAsync` 时将连接元数据（ProId、IsConnected=true、ConnectedAt）写入 `client_connection:{proId}` 缓存，并注册到 `__connection_registry__`
- [x] 3.3 在 `DeviceStatusHub.OnConnectedAsync` 中调用连接生命周期缓存方法，完成后广播 `ClientConnectionUpdate` 事件至 `client_connection` 组
- [x] 3.4 在 `DeviceStatusHub.OnDisconnectedAsync` 中调用连接生命周期缓存方法（更新 IsConnected=false、DisconnectedAt），完成后广播 `ClientConnectionUpdate` 事件
- [x] 3.5 新增 `ClientConnectionDto` 模型（ProId、ProName、IsConnected、ConnectedAt、DisconnectedAt）

## 4. 列表页 API 服务层

- [x] 4.1 在 `IDeviceStatusAppService` 接口中新增 `GetClientListAsync` 方法签名
- [x] 4.2 在 `DeviceStatusAppService` 中实现 `GetClientListAsync`：从连接注册表获取所有 ProId，读取每个 ProId 的连接记录，返回 ClientConnectionDto 列表，支持分页和 keyword 搜索
- [x] 4.3 验证 ABP 自动路由将新方法暴露为 `GET /api/app/device-status/client-list`

## 5. 列表页视图重写

- [x] 5.1 重写 `Views/ClientManagement/Index.cshtml`：移除原有逐设备行表格，改为客户端连接状态表格（列：客户端名称、连接状态、连接时间、断开时间、操作）
- [x] 5.2 实现页面加载时通过 `GET /api/app/device-status/client-list` 获取初始数据并渲染表格
- [x] 5.3 实现每行"查看详情"按钮，链接指向 `/ClientManagement/Detail?id={proId}`
- [x] 5.4 实现 SignalR 连接逻辑：连接 `/hubs/devicestatus`，订阅 `client_connection` 组，在 `ClientConnectionUpdate` 回调中更新对应客户端行
- [x] 5.5 实现连接状态指示器（实时更新/连接断开/重连中）和最后心跳时间显示
- [x] 5.6 实现 SignalR 断线时的 30 秒降级轮询机制

## 6. 详情页 API 服务层

- [x] 6.1 在 `IDeviceStatusAppService` 接口中新增 `GetClientDevicesAsync(string proId)` 方法签名
- [x] 6.2 在 `DeviceStatusAppService` 中实现 `GetClientDevicesAsync`：从缓存读取指定 ProId 数据，按 DeviceType 分组取最新记录，返回聚合结果；ProId 为空时抛 `BusinessException`
- [x] 6.3 验证 ABP 自动路由将新方法暴露为 `GET /api/app/device-status/client-devices?proId={proId}`

## 7. 详情页视图

- [x] 7.1 创建 `Views/ClientManagement/Detail.cshtml`：独立页面（`Layout = null`），包含"返回列表"链接、客户端标识展示区域
- [x] 7.2 实现 5 种设备类型的状态卡片 UI：地磅 Scale、摄像头 Camera、车牌识别 LPR、音响 Sound、打印机 Printer，每个卡片显示颜色编码状态指示器和最后更新时间
- [x] 7.3 实现页面加载时通过 `GET /api/app/device-status/client-devices?proId={id}` 获取初始数据并渲染卡片
- [x] 7.4 实现 SignalR 连接逻辑：连接 `/hubs/devicestatus`，订阅所有设备类型更新，在 `DeviceStatusUpdate` 回调中按 URL 参数 ProId 过滤并更新对应卡片
- [x] 7.5 实现连接状态指示器（实时更新/连接断开/重连中）和最后心跳时间显示
- [x] 7.6 实现 SignalR 断线时的 30 秒降级轮询机制

## 8. 验证

- [x] 8.1 验证 `/ClientManagement/Index` 页面正常渲染客户端连接状态表格，SignalR 实时更新和手动刷新工作正常
- [x] 8.2 验证 `/ClientManagement/Detail?id={proId}` 详情页正确显示设备在线卡片和 SignalR 实时更新
- [x] 8.3 验证旧路由 `/DeviceManagement/Index` 返回 404
- [x] 8.4 验证 `GET /api/app/device-status/client-list` API 返回正确连接数据
- [x] 8.5 验证 `GET /api/app/device-status/client-devices?proId={proId}` API 返回正确聚合数据
