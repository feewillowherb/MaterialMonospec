# Change: 接入 UrbanManagement OTA 控制面（版本/状态上报、Admin 可视化与远程触发更新）

## Why

目前 `MaterialClient.Urban`（Velopack OTA 客户端引擎）与 `UrbanManagement.Gateway`（`/updates/` 静态源）已完成数据面打通，但运维人员仍面临两个痛点：
1. 无法在 Admin 后台直观看到每台在线工控机当前运行的版本号（`AppVersion`）与 OTA 状态（`Idle / Downloading / ReadyToRestart / Failed`）；
2. 发布新版本或灰度包后，客户端只能被动等待 30 分钟后台轮询，无法在 Admin 中针对单台工控机按需下发「立即检查并更新」或指定灰度源（如 `/updates/urban-canary`）。

## What Changes

### 服务端（`repos/UrbanManagement`）
- **新增 OTA 控制面 DTO（`UrbanManagement.Core/Models/ClientOtaDtos.cs`）**：`ClientOtaStatusReportDto`、`OnlineClientOtaDto`、`TriggerClientOtaInputDto`、`TriggerClientOtaResultDto`、`ClientOtaInternalApi`。
- **扩展 `DeviceStatusHub`（向后兼容 1.0 客户端）**：
  - 新增内存注册表记录在线客户端的 `AppVersion`、`UpdateState`、`TargetVersion`、`FeedUrl`、`IsVelopackInstalled`、`Message`、`ReportedAtUtc`，断线自动清理；
  - 新增 Hub 方法 `ReportOtaStatus(ClientOtaStatusReportDto report)`；
  - 支持经 `IHubContext<DeviceStatusHub>` 向指定连接发送 `ReceiveOtaTriggerCommand(requestId, clientId, feedUrlOverride, applyWhenIdle)`。
- **新增 `ClientOtaAppService` + 跨容器转发**：
  - `UrbanManagement.Core/Services/ClientOtaAppService.cs`（`IClientOtaAppService` + `ClientOtaAppService`）；
  - `UrbanManagement.Realtime/Controllers/ClientOtaInternalController.cs`（`/internal/client-ota/**`）；
  - `UrbanManagement.Admin/Services/RemoteClientOtaAppService.cs`（复用 `Hosting:RealtimeBaseUrl` 转发至 Realtime）。
- **新增 Admin 页面「客户端更新」（`/client-updates`）**：
  - 在 `AdminLayout.razor` 增加侧边栏菜单项；
  - 展示在线客户端版本与更新状态表，支持对单台客户端一键触发「立即检查并更新」（可选填灰度 `FeedUrl` 覆写）。

### 客户端（`repos/MaterialClient`）
- **扩展 `IDeviceStatusSignalRClient` / `DeviceStatusSignalRClient`**：新增 `ReportOtaStatusAsync` 与 `OnReceiveOtaTriggerCommand`。
- **扩展 `IUrbanUpdateService` / `UrbanUpdateService`**：支持传入可选 `feedUrlOverride` 执行单次灰度源检查与下载。
- **新增 `ClientOtaControlService`（`MaterialClient.Urban/Services/Updates/`）**：
  - 启动与 SignalR 重连恢复后自动向 `DeviceStatusHub` 上报当前版本与 OTA 状态；
  - 收到 `ReceiveOtaTriggerCommand` 后立即执行检查/下载，并在 `applyWhenIdle == true` 时经过 `OffScale` 空闲门禁安全应用更新，同时将每阶段状态实时回传服务端。

## Capabilities

### New Capabilities
- `urban-ota-control-plane`: 定义在线客户端 OTA 版本与状态上报、Admin 管理页面可视化以及通过 SignalR 远程触发立即/灰度更新的端到端契约。

### Modified Capabilities
- 无现有 spec 修改。

## Impact

- **受影响仓库**：`repos/UrbanManagement` 与 `repos/MaterialClient`（Mode A：Trunk-direct，双仓同名分支 `add-urban-ota-control-plane`）。
- **向后兼容**：新增 Hub 方法与客户端监听事件，不修改 1.0 老客户端使用的任何既有协议或表结构；无数据库 Schema 变更。
