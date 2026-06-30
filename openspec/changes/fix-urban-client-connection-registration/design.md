## Context

MaterialClient 通过 `DeviceStatusSignalRClient` 连接 UrbanManagement `DeviceStatusHub`。服务端在**首次收到带 `ProId` 的 `UploadStatus`** 时调用 `CacheClientConnectedAsync` 并广播 `ClientConnectionUpdate` 至 `client_connection` SignalR 组。

实测日志显示：桌面端 `ConnectionId=5YFz_...` 已完成 `VerifyJwtAsync` 与 `RegisterLogCapability`，但无 `DeviceStatusService: Cached client connected` 日志，项目管理页显示「未注册」。

当前 `OnConnectionRestoredAsync` 顺序：

```
FlushMessageQueue → SignalRConnectionRestoredEventData (Republish) → SyncProjectLicenseFromServerAsync
```

`SignalRConnectionRestoredHandler` 调用 `SharedDeviceStatusTrackerRegistry.RepublishActiveStatuses()`，依赖 tracker 已 `Register`。SignalR 在 `MaterialClientUrbanModule.OnApplicationInitializationAsync` 中启动，而 `SharedDeviceStatusTracker.StartMonitoring()` 在 `App.StartMainWindowServices` 中才执行，存在竞态。

UrbanManagement `ProjectManagement.razor` 已监听 `ClientConnectionUpdate`，但未调用 Hub 方法 `SubscribeClientConnection()`，浏览器连接不在 `client_connection` 组内。fallback 轮询仅在 `_hubConnection.State != Connected` 时执行，导致 Hub 已连接时页面永不刷新客户端列表。

## Goals / Non-Goals

**Goals:**

- 桌面端 SignalR 连接恢复后，可靠触发至少一次带有效 `ProId` 的 `UploadStatus`，使服务端写入连接注册表。
- 项目管理页在 Hub 连接/重连后加入 `client_connection` 组，收到 `ClientConnectionUpdate` 时刷新列表。
- 保持现有 Hub 登记触发点（`UploadStatus` 首次 ProId 映射），不引入 Hub API 破坏性变更。

**Non-Goals:**

- 不在 `VerifyJwtAsync` 或 `OnConnectedAsync` 中单独登记客户端（避免与防篡改、连接生命周期语义重复）。
- 不修改 `GetClientListAsync` 或缓存 schema。
- 不处理 COM3 地磅等硬件问题。

## Decisions

### D1: 将 `SignalRConnectionRestoredEventData` 发布移到 `SyncProjectLicenseFromServerAsync` 之后

**选择**：`OnConnectionRestoredAsync` 新顺序：

```
FlushMessageQueue → SyncProjectLicenseFromServerAsync → Publish(SignalRConnectionRestoredEventData)
```

**理由**：`DeviceStatusEventHandler` 从 `LicenseInfo` 读取 `ProId`；先完成授权同步（含 `VerifyJwtAsync`）再 Republish，保证消息含有效 `ProId`。与实测中 JWT 验签成功但无 `Cached client connected` 的现象一致。

**备选**：在 `VerifyJwtAsync` 成功后 Hub 端登记 → 需改 UrbanManagement Hub，与现有「UploadStatus 驱动登记」设计分叉，弃用。

### D2: 在授权同步成功后增加 tracker 兜底 Republish

**选择**：`SyncProjectLicenseFromServerAsync` 各成功返回路径末尾（或 `OnConnectionRestoredAsync` 最后），注入 `ISharedDeviceStatusTrackerRegistry` 并调用 `RepublishActiveStatuses()`。

**理由**：即使事件总线异步处理仍有竞态，直接调用 registry 可在 tracker 已注册时立即补发；tracker 未注册时无操作（与现有一致）。

**备选**：延迟 Task.Delay 重试 → 不可靠，弃用。

### D3: `ProjectManagement.razor` 在 `StartAsync` 与 `Reconnected` 后调用 `SubscribeClientConnection`

**选择**：

```csharp
await _hubConnection.StartAsync();
await _hubConnection.InvokeAsync("SubscribeClientConnection");
```

`Reconnected` 回调中重复调用。

**理由**：Hub 已实现 `SubscribeClientConnection`，spec 要求接收 `ClientConnectionUpdate` 但未强制调用此方法；补齐即可。

### D4: 不修改 fallback 轮询条件

**选择**：保持「仅 Hub 断开时 30s 轮询」；依赖 `SubscribeClientConnection` + `ClientConnectionUpdate` 实现实时更新。

**理由**：登记后 Hub 会广播事件；修复订阅后无需增加 Connected 状态下的轮询流量。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 授权同步失败时不再 Republish | 仅跳过登记；设备状态仍可在 tracker 启动后由定时器上报 |
| 重复 `UploadStatus` 导致多余流量 | 服务端 `isNewMapping` 仅首次写注册表；后续为状态更新 |
| tracker 仍未注册时兜底无效 | 设备监控启动后定时器仍会触发 `UpdateDeviceOnline` 首次变更上报 |

## Migration Plan

1. MaterialClient：改 `DeviceStatusSignalRClient`，本地验证日志出现 `Cached client connected`（UrbanManagement 侧）。
2. UrbanManagement：改 `ProjectManagement.razor`，不重启服务亦可热更新 Blazor（视部署方式）。
3. 手动验证：打开项目管理页 → 启动/激活客户端 → 状态由「未注册」变为「在线」无需 F5。

## Open Questions

- 无。实现范围明确，无需新配置项。
