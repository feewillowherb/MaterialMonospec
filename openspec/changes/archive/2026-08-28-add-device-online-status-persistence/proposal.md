## Why

UrbanManagement 将客户端在线/离线与设备类型状态仅写在分布式缓存（约 24h TTL）中，服务重启或缓存过期后项目管理页会误显示「未注册」，设备弹窗详情丢失，且无法可靠展示「最后在线时间」。需要把**客户端连接态**与**设备在线详情（当前态）**一并落库，作为跨重启可恢复的权威数据源。

同时，未来 Urban V2 将支持「1 项目 ↔ 最多 4 台机器码 / 多场地同时在线」（见 `docs/2026-08-25-urban-v2-four-machine-code-binding`）。落库模型 MUST 按**项目下多客户端实例**设计，禁止「每 ProId 仅一行」。

## What Changes

- **客户端连接态**落库；粒度 = **`(ProId, ClientId)`**（`ClientId` = 机器码/客户端实例，与 `DeviceStatusMessage.ClientId` 一致）。
- **设备在线详情（当前态）**落库；粒度 = **`(ProId, ClientId, DeviceType)`**（Scale / Camera / LPR / Sound / Printer 等），保存最新 `Status`、`LastUpdateTime`、可选 `AdditionalData`；供 `GetClientDevicesAsync` 与项目管理「设备」弹窗使用。
- SignalR：`UploadStatus` upsert 设备详情行；连接映射/断线按实例更新连接态，并将该实例下设备详情标为 Offline（不影响同项目其它 `ClientId`）。
- 查询以数据库为准；缓存仅可作可选写穿旁路（连接态与设备消息队列均可降级）。
- 项目管理页「最后同步时间」改为「最后在线时间」（项目级多实例聚合）。
- 不以全量设备**事件历史审计**为目标（不强制启用 append-only `DeviceStatusLog`）；不实现四机授权/槽位绑定。

## Capabilities

### New Capabilities

- `device-online-status-persistence`: 多实例连接态 + 设备类型当前态落库、查询权威源、SignalR 写库、项目聚合与设备弹窗读库。

### Modified Capabilities

- `abp-typed-device-cache`: 连接态与设备状态缓存降级为旁路；不得作为唯一真相。
- `signalr-device-status-upload`: Hub 按 `ClientId` 落库连接态与设备详情；禁止「一机断线 → 整项目离线/清设备」。
- `device-status-query`: `GetClientListAsync` / `GetClientDevicesAsync` MUST 从数据库读取。
- `project-client-merge`: 「最后在线时间」、客户端徽标聚合；设备弹窗详情来自落库。
- `blazor-project-management`: 列文案/绑定；设备弹窗展示落库详情（含多实例时可区分 `ClientId`）。

## Impact

- **仓库**：`repos/UrbanManagement`（主）；MaterialClient 仍用现有 `UploadStatus`。
- **模块**：`DeviceStatusHub`、`DeviceStatusService`、`DeviceStatusAppService`、EF + migration、`ProjectManagement.razor`。
- **数据**：`ClientOnlineStatus` `(ProId, ClientId)`；`ClientDeviceOnlineStatus`（或同等命名）`(ProId, ClientId, DeviceType)`；可选可空 `Slot` 仅预留。
- **API**：实例级连接 DTO；`ClientDeviceSummaryDto` 宜含 `ClientId` 以支持多机详情。
- **前瞻**：四机绑定调研；在线/设备表不替代授权槽位表。
