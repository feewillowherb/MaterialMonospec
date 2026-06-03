## Why

UrbanManagement 的"设备管理"模块名称无法准确反映其业务语义——该模块实际监控的是客户端（MaterialClient 桌面端）及其下属设备的运行状态，而非独立设备的管理。同时，当前列表页以逐设备行为粒度展示（一行 = 一个设备类型），运维人员难以快速掌握每个客户端是否在线。需要将列表页重构为按客户端展示 SignalR 长连接状态（连接是否存在、连接时间、断开时间），并提供设备级别的详情页查看。

## What Changes

- **BREAKING** 将 UrbanManagement 导航菜单中的"Device Management"更名为"Client Management"（中文显示"客户端管理"），同步更新页面标题 `<title>` 标签。
- **BREAKING** 将控制器 `DeviceManagementController` 重命名为 `ClientManagementController`，路由由 `/DeviceManagement/Index` 变更为 `/ClientManagement/Index`。
- 将 `Views/DeviceManagement/` 目录重命名为 `Views/ClientManagement/`。
- **重构列表页**：将列表页从"逐设备行"改为"逐客户端行"，一行对应一个客户端（ProId），展示 SignalR 长连接状态（在线/离线、连接时间、断开时间），并提供"查看详情"入口跳转至设备在线详情页。
- 新增客户端设备在线详情页面（`ClientManagement/Detail`），以客户端（ProId/ClientId）为维度，聚合展示该客户端下所有设备类型的实时在线状态，提供颜色编码的状态指示器和最后更新时间。
- 扩展 `DeviceStatusHub` 在连接/断开时将连接元数据写入分布式缓存，支持列表页的连接状态查询。
- 服务端新增列表查询 API（`GetClientListAsync`）读取客户端连接记录，以及详情查询 API（`GetClientDevicesAsync`）读取指定客户端的设备状态。
- MaterialClient 侧无需新增接口——现有 SignalR 连接和 `DeviceStatusMessage` 上报机制保持不变。

## Capabilities

### New Capabilities

- `client-management-module`: 将"设备管理"模块重命名为"客户端管理"，涵盖控制器重命名、视图目录迁移、导航菜单和页面标题的文本更新，列表页重构为按客户端展示 SignalR 长连接状态（在线/离线、连接时间、断开时间），以及 Hub 连接生命周期缓存机制。
- `client-device-online-detail`: 以客户端为维度的设备在线详情视图，在详情页中聚合展示该客户端下所有设备类型的实时在线/离线状态，复用现有 SignalR 推送和分布式缓存查询能力。

### Modified Capabilities

<!-- 无需修改现有 spec——signalr-device-status-upload 的消息协议不变，device-status-bar 是 MaterialClient 侧的 UI 控件 spec 且不受 Web 端重命名影响。 -->

## Impact

### UrbanManagement (主仓库)

| 变更区域 | 文件/模块 | 变更说明 |
|---|---|---|
| 控制器 | `Controllers/DeviceManagementController.cs` | 重命名为 `ClientManagementController`，路由更新 |
| 视图 | `Views/DeviceManagement/Index.cshtml` | 迁移至 `Views/ClientManagement/Index.cshtml`，重构为客户端连接状态列表页 |
| 视图 (新增) | `Views/ClientManagement/Detail.cshtml` | 新增设备在线详情页面 |
| 布局 | `Views/Shared/_Layout.cshtml` | 导航链接文本和路由更新 |
| Hub | `Hubs/DeviceStatusHub.cs` | 扩展 OnConnectedAsync/OnDisconnectedAsync 缓存连接元数据到分布式缓存，并广播 `ClientConnectionUpdate` 事件至浏览器端 |
| 服务层 | `Services/IDeviceStatusAppService.cs` | 新增 `GetClientListAsync`（客户端连接列表）和 `GetClientDevicesAsync`（单客户端设备详情） |
| 服务层 | `Services/DeviceStatusAppService.cs` | 实现两个查询方法 |
| 模型 (新增) | `Models/ClientConnectionDto.cs` | 客户端连接状态 DTO（ProId、ProName、IsConnected、ConnectedAt、DisconnectedAt） |
| 模型 (新增) | `Models/ClientDeviceSummaryDto.cs` | 客户端设备在线汇总 DTO（Detail 页用） |

### MaterialClient (配合仓库)

| 变更区域 | 影响评估 |
|---|---|
| SignalR 上报协议 | **无变更**——`DeviceStatusMessage` 字段和 `UploadStatus` 方法保持不变 |
| 设备状态追踪 | **无变更**——`SharedDeviceStatusTracker` 和 `DeviceStatusEventHandler` 逻辑不受影响 |
| 服务端 API | **无变更**——新增的聚合查询基于服务端已有的分布式缓存数据 |

### 用户影响

- 书签/收藏链接中旧的 `/DeviceManagement/Index` 路径将失效（404），需更新。
- 旧路由无重定向策略（需求明确不需要向后兼容）。
