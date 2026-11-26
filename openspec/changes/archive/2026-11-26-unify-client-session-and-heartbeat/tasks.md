# Tasks: unify-client-session-and-heartbeat

> 目标仓库：`repos/UrbanManagement` 与 `repos/MaterialClient`（Mode A：Trunk-direct，双仓同名分支 `unify-client-session-and-heartbeat`）。
> 1.0 兼容硬约束：保留 `DeviceStatusHub.UploadStatus` 与 `RegisterLogCapability` 不破坏。

## 1. `repos/UrbanManagement` 会话、心跳与 O7/O8 修复

- [x] 1.1 在 `UrbanManagement.Core/Models/ClientSessionDtos.cs` 新增 `ClientSessionHelloDto`、`ClientHeartbeatDto`、`ClientDeviceSnapshotDto`。
- [x] 1.2 更新 `UrbanManagement.Core/Services/DeviceStatusService.cs`：规范化 `CacheMessageAsync` / `MarkInstanceDevicesOfflineInCacheAsync` 的 `ProId` 键（修复 O7 大小写不匹配），并新增 `HandleHeartbeatAsync(ClientHeartbeatDto)`。
- [x] 1.3 更新 `UrbanManagement.Core/Hubs/DeviceStatusHub.cs`：新增 `RegisterSession`、`ClientHeartbeat` 与 `_activeClientConnections` 活跃连接表，在 `OnDisconnectedAsync` 中防止旧连接晚断误杀已重连的新连接（修复 O8），并同步更新 OTA 注册表。
- [x] 1.4 修复 `UrbanManagement.Admin/Pages/ProjectManagement.razor`：`OpenDeviceModal` 使用 `project.SourceProId`（空时回退 `project.Id`）。

## 2. `repos/MaterialClient` 统一身份、O2/O3 修复与 30s 心跳

- [x] 2.1 新增 `MaterialClient.Common/Utils/ClientIdentityResolver.cs` 与 `MaterialClient.Common/Models/ClientSessionPayloads.cs`。
- [x] 2.2 更新 `MaterialClient.Common/Services/DeviceStatusSignalRClient.cs`：修复 `_isStarted` 首连失败后阻断发送（O2），新增 `RegisterSessionAsync` 与 `SendHeartbeatAsync`。
- [x] 2.3 更新 `MaterialClient.Common/Events/DeviceStatusEventHandler.cs`：修复 `ShouldThrottle` 假节流、移除 `[UnitOfWork]` 并内存缓存 `ProId`/`ProName`、接入 `ClientIdentityResolver`（修复 O3）。
- [x] 2.4 更新 `ClientLogPullService.cs` 与 `ClientOtaControlService.cs` 统一使用 `ClientIdentityResolver`（修复 L2）。
- [x] 2.5 新增 `MaterialClient.Urban/Backgrounds/ClientHeartbeatBackgroundWorker.cs`（30s 周期心跳 + 重连立即注册/补发），并在 `MaterialClientUrbanModule.cs` 注册。

## 3. 单元测试与双仓构建验证

- [x] 3.1 补充 `MaterialClient.Common.Tests`（`ClientIdentityResolverTests`、`DeviceStatusEventHandler` 真节流测试）。
- [x] 3.2 分别在 `repos/MaterialClient` 与 `repos/UrbanManagement` 执行 `dotnet build` 与 `dotnet test`，确保双仓编译 0 错误、单测全绿。
