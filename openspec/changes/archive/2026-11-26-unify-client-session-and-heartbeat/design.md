# Design: 统一客户端会话、30 秒轻量心跳与核心缺陷修复

## Context

本次变更是 `docs/2026-11-26-urban-recycle-logging-online-audit/03-目标重构设计与1.0兼容方案.md` 中的 **Change 1**。目标是在保持 1.0 客户端完全兼容的前提下，将客户端身份、会话注册、30 秒心跳保活与外设状态快照统一到稳定、无热路径 SQLite/SQL Server 写入的架构上。

## Decisions

### 1. 统一客户端身份：`ClientIdentityResolver`

在 `MaterialClient.Common/Utils/ClientIdentityResolver.cs` 定义纯静态方法（无 DI）：

- `Resolve(IConfiguration configuration, string? machineCode = null)`：
  1. 若 `configuration["Client:Id"]` 非空白，返回 `Trim()`（截断至 100 字符）；
  2. 否则若 `machineCode` 非空白，返回 `{Environment.MachineName}-{shortMachineCode}`（短码取前 8 位，避免克隆镜像撞名且保留可读主机名）；
  3. 否则返回 `Environment.MachineName`。

### 2. `DeviceStatusSignalRClient` 状态机修复（O2）

- `UploadStatusAsync` 不再依赖 `_isStarted` 布尔标志，直接检查 `_connection?.State == HubConnectionState.Connected`；
- 重连循环成功连接后也同步设置 `_isStarted = true`，确保与历史代码语义一致；
- 新增 `RegisterSessionAsync(ClientSessionHello)` 与 `SendHeartbeatAsync(ClientHeartbeatPayload)`，未连接时静默跳过（心跳是周期性幂等操作，无需入队积压）。

### 3. `DeviceStatusEventHandler` 真正节流与去 `[UnitOfWork]`（O3）

- 节流逻辑：在 `MinSendInterval`（1 秒）内，如果同一 `DeviceType` 的 `Status` 与上次已发送状态完全相同，直接 `return` 跳过发送；如果 `Status` 发生变化，立即放行并更新 `_lastSendTimes` 与 `_lastSentStatus`。
- 移除 `[UnitOfWork]`：使用静态缓存（5 分钟 TTL）缓存 `ProId` / `ProName`，仅在缓存缺失或过期时读取一次 `_licenseService.GetCurrentLicenseAsync()`，消除高频状态事件对 SQLite 的事务锁竞争。

### 4. `DeviceStatusHub` 防重连竞态误杀（O8）与 1.0 兼容

- 在 `DeviceStatusHub` 维护最新活跃连接表 `_activeClientConnections`（Key = `{normalizedProId}:{clientId}`，Value = `ConnectionId`）；
- `UploadStatus`、`RegisterSession`、`ClientHeartbeat` 均刷新 `_activeClientConnections` 为当前 `Context.ConnectionId`；
- `OnDisconnectedAsync` 中，仅当 `_activeClientConnections` 中记录的当前 `ConnectionId` **等于** 正在断开的 `Context.ConnectionId` 时，才移除并调用 `UpsertClientDisconnectedAsync`；若已被新连接接管，则直接忽略旧连接断开事件。

### 5. `DeviceStatusService` 规范化 `ProId` 键（O7）与心跳处理

- `CacheMessageAsync` 与 `MarkInstanceDevicesOfflineInCacheAsync` 统一先通过 `ProIdValidator.TryParseWireProId` 将 `ProId` 规范化为标准小写 `Guid` 字符串再读写 Redis `_deviceStatusCache`，与 `_clientConnectionCache` 和 Admin 查询口径 100% 一致；
- `HandleHeartbeatAsync(ClientHeartbeatDto)`：调用 `TouchOnlineAsync` 刷新在线 TTL，并将心跳中携带的 `Devices` 快照批量合入规范化 `ProId` 的 `_deviceStatusCache`（仅写 Redis，不写 EF）。
