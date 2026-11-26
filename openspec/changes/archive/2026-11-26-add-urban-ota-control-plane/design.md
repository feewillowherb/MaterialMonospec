# Design: UrbanManagement + MaterialClient OTA 控制面

## Context

`UrbanManagement` 采用多角色容器部署：`um-admin` 提供 Blazor 管理界面，`um-realtime` 承载 `DeviceStatusHub`（SignalR）。两者之间已通过 `/internal/**` 内部 HTTP API 通信（如 `RemoteClientLogAppService` → `ClientLogInternalController`）。

OTA 控制面完全沿用这一成熟模式，零新增基础设施依赖、零数据库迁移。

## Decisions

### 1. SignalR 协议契约（向后兼容 1.0）

- **客户端 → 服务端**：`ReportOtaStatus(ClientOtaStatusReportDto report)`
  - 客户端在启动初始化、SignalR 重连恢复（`SignalRConnectionRestoredEventData`）、以及每次 OTA 检查/下载/应用/延后状态变化时调用；
  - 服务端 `DeviceStatusHub` 将最新状态存入静态线程安全注册表（按 `ClientId` 索引，绑定 `ConnectionId`），在 `OnDisconnectedAsync` 中按 `ConnectionId` 自动清理；
  - 1.0 老客户端不调用该方法，不影响其连接与既有心跳。
- **服务端 → 客户端**：`ReceiveOtaTriggerCommand(string requestId, string clientId, string? feedUrlOverride, bool applyWhenIdle)`
  - `ClientOtaAppService.TriggerUpdateAsync` 从 `DeviceStatusHub` 查找 `ClientId` 对应在线 `ConnectionId`，通过 `IHubContext<DeviceStatusHub>` 定向推送；
  - 客户端 `ClientOtaControlService` 校验 `clientId` 匹配后调用 `IUrbanUpdateService.CheckAndDownloadUpdateAsync(feedUrlOverride)`，若 `applyWhenIdle` 且 `ReadyToRestart` 则调用 `TryApplyPendingUpdateAsync()`（仍受 `AttendedWeighingStatus.OffScale` 空闲门禁保护），并在前后各上报一次最新状态。

### 2. 跨容器转发与 Admin UI

- `ClientOtaInternalController` 暴露 `GET /internal/client-ota/online-clients` 与 `POST /internal/client-ota/trigger-update`（被 `um-gateway` `/internal` 拦截，仅容器内网可达）；
- `RemoteClientOtaAppService` 在 `UrbanManagementAdminModule` 注册，将 `IClientOtaAppService` 转发至 `Hosting:RealtimeBaseUrl`；
- `ClientUpdates.razor`（`/client-updates`）复用现有 Layui 卡片与表格样式（仅使用中文业务文案），提供在线客户端列表、状态标签、可选灰度源输入框及「立即检查并更新」操作按钮。

### 3. 编码规范对齐

- `UrbanManagement`：接口与实现同文件（`ClientOtaAppService.cs`）、`[AutoConstructor]`、`ApplicationService` + DTO、`record` 替代 tuple；
- `MaterialClient`：单一数据源、命名 `record`、`ISingletonDependency`、SDK/SignalR 回调不切 UI 线程。
