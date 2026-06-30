## Why

激活后重启已使 MaterialClient 成功连接 SignalR 并完成 JWT 验签，但 UrbanManagement 项目管理页仍显示「未注册」。根因有两处：（1）桌面端在 `OnConnectionRestoredAsync` 中于授权同步**之前**触发设备状态重发，且 SignalR 可能在 `SharedDeviceStatusTracker` 注册前即已连接，导致带 `ProId` 的 `UploadStatus` 未触发服务端 `CacheClientConnectedAsync`；（2）`ProjectManagement.razor` 未调用 `SubscribeClientConnection` 加入 `client_connection` 组，且轮询仅在浏览器 Hub 断开时执行，页面打开后无法自动刷新客户端列表。

## What Changes

- 调整 MaterialClient `DeviceStatusSignalRClient.OnConnectionRestoredAsync` 顺序：在 `SyncProjectLicenseFromServerAsync` 完成后再触发设备状态重发（`SignalRConnectionRestoredEventData`），确保 `UploadStatus` 携带有效 `ProId` 并登记连接注册表。
- 在 `SyncProjectLicenseFromServerAsync` 成功路径末尾增加兜底：若设备状态跟踪器已注册则再次 `RepublishActiveStatuses`，避免时序竞态。
- UrbanManagement `ProjectManagement.razor`：Hub 连接成功及 `Reconnected` 后调用 `SubscribeClientConnection`，以接收 `ClientConnectionUpdate` 实时刷新。
- 保持现有 Hub 登记语义不变：仍以首次带 `ProId` 的 `UploadStatus` 触发 `CacheClientConnectedAsync`（不改为仅在 `VerifyJwtAsync` 登记，避免与现有防篡改流程耦合过深）。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `signalr-device-status-upload`：明确连接恢复后必须在授权信息可用时上报设备状态以完成客户端连接登记。
- `project-client-merge`：明确项目管理页 SignalR 须加入 `client_connection` 组并接收 `ClientConnectionUpdate`。
- `client-management-module`：澄清浏览器端须订阅 `client_connection` 组方能收到连接状态广播（与 Hub 既有 `SubscribeClientConnection` 方法对齐）。

## Impact

- **MaterialClient**（`repos/MaterialClient`）：
  - `DeviceStatusSignalRClient.cs`：调整 `OnConnectionRestoredAsync` 顺序与兜底重发
  - 可能微调 `SignalRConnectionRestoredHandler` 或调用点（若需）
- **UrbanManagement**（`repos/UrbanManagement`）：
  - `Pages/ProjectManagement.razor`：`SubscribeClientConnection` + `Reconnected` 重订阅
- **无 API 契约变更**；无数据库迁移
