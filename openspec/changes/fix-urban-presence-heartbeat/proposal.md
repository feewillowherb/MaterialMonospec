## Why

UM 项目管理「在线」依赖 Redis live 键（TTL ≈ `2× ClientTimeout`，默认 ~120s）。键只在 connect upsert / 合格 `UploadStatus` 时写入；**空键时 refresh 直接 return**，同连接后续上报也常无法唤醒。另有两类现场需求：

1. **有 SignalR 的 Urban**：安静后假离线；过期后再上报也醒不过来。
2. **仅用 `LegacyApiController` / `/Api/Post` 的旧客户端（无 SignalR）**：从不写在线键，管理端看不到在线。

客户端周期心跳部署代价高，本 change 在 **UrbanManagement 双入口 Touch** 解决续期与唤醒；MaterialClient 心跳留给后续健壮性。

## What Changes

- UrbanManagement：引入统一 **TouchOnline**（键在则续 TTL/LastSeen；**键不在则重建** `IsConnected=true`）
- **SignalR `UploadStatus`**：凡带有效 `ProId`+`ClientId` 即 Touch（不依赖「本 ConnectionId 首次 mapping」才 upsert）
- **`ReceiveAsync`**（含 Legacy `LegacyApiController` → `LegacyGovSync` → Receive）：收单成功后 Touch
  - Legacy：`ClientId` **固定**为 `legacy:{AccessCode}`（AccessCode 与查库一致地 trim/规范化）
  - Modern：有 `SubmitMachineCode` 时以其为 `ClientId`；缺失则跳过 Touch（不写 ProId-only 行）
- **不**新增 Hub heartbeat 方法；**不**改 MaterialClient 周期 republish（Out-of-Scope / backlog）
- 验收：SignalR 路径用 `urban-signalr-online-probe` 验证「过期后再 UploadStatus 可唤醒」；Legacy 路径用成功 Post 后 client-list 出现 `legacy:{AccessCode}` 且 `isConnected=true`（可手测或补轻量采证）

## Capabilities

### New Capabilities

- （无）

### Modified Capabilities

- `device-online-status-persistence`：TouchOnline 语义（含空键重建）；Legacy / Receive 业务活跃可续 live 在线；禁止仅因 TTL 过期且同连接仍有合格上报而永久假离线
- `signalr-device-status-upload`：合格 `UploadStatus` MUST Touch 连接在线态（含空键重建）；仍禁止新 Hub 方法；**不**要求本 change 做客户端周期 heartbeat

## Impact

- **UrbanManagement**：`DeviceStatusService`（或等价 presence touch API）、`DeviceStatusHub.UploadStatus`、`UrbanWeighingRecordAppService.ReceiveAsync`、`UrbanWeighingRecordReceiveInputDto.FromLegacySync`（写入/传递 Legacy ClientId 所需 AccessCode）
- **MaterialClient**：**无代码变更**（本 change）
- **Pipelines**：`urban-signalr-online-probe` 回归唤醒场景；Legacy 在线可另补或手测
- **依赖**：Redis live 主存（`fix-urban-signalr-disconnect-storm`）
- **非目标**：客户端周期 `RepublishCurrentStatuses`；Hub 连接图定时扫作唯一权威；加长 TTL 作唯一修复；Web Hub 订阅/轮询；JWT/BasePlatform
- **Backlog（健壮性）**：有 SignalR 的 Urban 客户端周期 presence，或 UM 按 Hub 映射续期——另开 change
