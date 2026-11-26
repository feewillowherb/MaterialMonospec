# Change: 统一客户端会话、30 秒轻量心跳并修复在线/设备监控核心缺陷（兼容 1.0）

## Why

根据 [`docs/2026-11-26-urban-recycle-logging-online-audit/`](../../docs/2026-11-26-urban-recycle-logging-online-audit/00-调研总览.md) 的源码级审计，当前 `MaterialClient` 与 `UrbanManagement` 的在线状态与设备监控存在多个 P0 级缺陷：
1. **无定时心跳（O4）**：仅靠外设状态翻转驱动 `UploadStatus`，健康工控机易触发 Redis TTL 过期被误判离线；
2. **`_isStarted` 门禁死锁（O2）**：开机首连失败后进入重连循环，重连成功但 `_isStarted` 仍为 `false`，后续所有 `UploadStatusAsync` 永久只入队不发送；
3. **假节流与热路径 `[UnitOfWork]`（O3）**：`DeviceStatusEventHandler` 命中节流后未 `return` 照发不误，且每次事件都开启 SQLite 事务读取 License；
4. **身份口径分裂与撞名（L2 / O9）**：`DeviceStatusEventHandler`、`ClientLogPullService`、`ClientOtaControlService` 三处各自拼接 `ClientId`；
5. **1.0 在线但设备为空（O7）**：设备 Redis 缓存未做 `Guid` 规范化导致大小写不匹配，`ProjectManagement.razor` 弹窗传 `project.Id` 而非 `SourceProId`；
6. **重连竞态误杀（O8）**：旧连接晚断触发 `OnDisconnectedAsync` 未校验当前最新 `ConnectionId`，把已重连的新连接一把打成离线。

## What Changes

### 服务端（`repos/UrbanManagement`）
- **新增统一会话与心跳 DTO（`UrbanManagement.Core/Models/ClientSessionDtos.cs`）**：`ClientSessionHelloDto`、`ClientHeartbeatDto`、`ClientDeviceSnapshotDto`（命名 `record`）。
- **增强 `DeviceStatusService.cs`**：
  - 规范化 `CacheMessageAsync` 与 `MarkInstanceDevicesOfflineInCacheAsync` 的 `ProId` 缓存键为标准小写 `Guid` 字符串，消除 Redis Key 大小写不匹配（O7）；
  - 新增 `HandleHeartbeatAsync(ClientHeartbeatDto)`：刷新 `_clientConnectionCache`（TTL 刷新、不写 EF 热路径）并同步刷新本次心跳携带的外设快照至规范化 `ProId` 的 `_deviceStatusCache`。
- **增强 `DeviceStatusHub.cs`（完全保留 1.0 `UploadStatus` 与 `RegisterLogCapability` 兼容）**：
  - 新增 `RegisterSession(ClientSessionHelloDto)` 与 `ClientHeartbeat(ClientHeartbeatDto)`；
  - 维护每个 `(ProId, ClientId)` 的最新活跃 `ConnectionId`，在 `OnDisconnectedAsync` 中仅当断开连接等于最新活跃连接时才标记离线，消除闪断重连误杀（O8）。
- **修复 `ProjectManagement.razor`**：`OpenDeviceModal` 使用 `project.SourceProId`（空时回退 `project.Id`）查询设备列表（O7）。

### 客户端（`repos/MaterialClient`）
- **新增统一身份解析器（`MaterialClient.Common/Utils/ClientIdentityResolver.cs`，纯静态无 DI）**：统一 `Client:Id`（非空白优先）→ `MachineCode` / `Environment.MachineName` 规则，并在 `DeviceStatusEventHandler`、`ClientLogPullService`、`ClientOtaControlService` 中统一引用。
- **修复 `DeviceStatusSignalRClient.cs`（O2）并新增会话/心跳 RPC**：
  - 移除 `UploadStatusAsync` 对 `_isStarted` 的错误阻断，直接以 `_connection?.State == HubConnectionState.Connected` 判定发送，重连成功后同步置 `_isStarted = true`；
  - 新增 `RegisterSessionAsync` 与 `SendHeartbeatAsync`。
- **修复 `DeviceStatusEventHandler.cs`（O3）**：
  - 真正拦截节流窗口内相同状态的重复发送；
  - 移除 `[UnitOfWork]`，内存缓存 `ProId`/`ProName` 避免热路径 SQLite 事务。
- **新增 30 秒轻量心跳后台任务（`MaterialClient.Urban/Backgrounds/ClientHeartbeatBackgroundWorker.cs`）**：
  - 每 30 秒通过 `SendHeartbeatAsync` 上报在线保活、`ProductCode=5001`、`AppVersion`、`OtaState` 与当前外设快照；
  - SignalR 建连/重连恢复后立即触发一次 `RegisterSessionAsync` + `SendHeartbeatAsync`。

## Capabilities

### New Capabilities
- `client-session-heartbeat`: 定义统一的客户端身份解析、SignalR `RegisterSession` + 30 秒 `ClientHeartbeat` 保活与外设快照同步、重连防误杀及 1.0 `UploadStatus` 向后兼容契约。

### Modified Capabilities
- 无现有 spec 修改。

## Impact

- **受影响仓库**：`repos/UrbanManagement` 与 `repos/MaterialClient`（Mode A：Trunk-direct，双仓同名分支 `unify-client-session-and-heartbeat`）。
- **向后兼容**：1.0 客户端继续使用 `UploadStatus` 与 `RegisterLogCapability`，不受任何破坏；暂不修改 `MaterialClient.Recycle` 宿主代码（共享层已面向多宿主设计）。
- **数据层**：无数据库 Schema 或迁移变更。
