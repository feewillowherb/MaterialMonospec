## Context

- Redis live TTL = `max(60, ClientTimeoutIntervalSeconds)×2`（默认 120s）；transport keepalive **不**续键。
- 空键时 `TryRefreshLastSeenInCacheAsync` / 设备详情路径 `connection == null` → **不重建**；`UpsertClientConnectedAsync` 仅在 Hub **首次** ProId+ClientId mapping 调用 → 同连接 TTL 过期后上报常无法唤醒。
- Legacy 客户端无 SignalR，只走 `LegacyApiController` → `ReceiveAsync`，今天不写在线 Redis → 管理端无「在线」。
- 约束：工控升级贵 → **本 change 只改 UM**；禁止新 Hub heartbeat 方法；不恢复 Web Hub 订阅/轮询。

## Goals / Non-Goals

**Goals:**

- 统一 `TouchOnline(ProId, ClientId, ProName?)`：续期或**重建** live 在线。
- SignalR 合格 `UploadStatus` 一律 Touch。
- `ReceiveAsync` 成功后按约定 ClientId Touch（Legacy = `legacy:{AccessCode}`；Modern = `SubmitMachineCode`）。
- 修复「TTL 过期后同连接上报唤不醒」。
- Legacy 无 Hub 时，成功过磅即可在 UM 显示在线（语义：业务活跃在 TTL 内）。

**Non-Goals:**

- MaterialClient 周期 presence / heartbeat（backlog）。
- 仅靠加大 `ClientTimeout` / live TTL 掩盖问题。
- Hub 连接图定时扫作为本 change 必做项（可另开；安静 Urban 无上报时仍可能假离线）。
- 新 Hub 方法、Web 轮询、EF 热路径回退。
- Legacy 多机拆分实例（同 AccessCode 共用一个 ClientId，已接受）。

## Decisions

### D1: UM 统一 TouchOnline（首选）

**选择**：在 `DeviceStatusService`（或由其暴露的 presence API）实现 Touch：缺键则等价 `UpsertClientConnected`；有键则续 TTL 并更新 LastSeen（可保留 LastSeen 节流，但 **TTL 必须续**）。

**理由**：一处语义，供 Hub 与 Receive 复用；修空键洞。

**备选否决**：只加长 TTL；只改客户端心跳（部署贵，且不覆盖 Legacy）。

### D2: SignalR UploadStatus 总是 Touch

**选择**：`HandleStatusUploadAsync`（或 Hub 在每次合格上报时）调用 Touch，**不**再依赖「仅 `isNewMapping` 才 UpsertConnected」作为唯一建键路径。首次 mapping 广播行为可保留。

**理由**：同连接过期后仍能唤醒。

### D3: Receive / Legacy 业务活跃 = presence

**选择**：`ReceiveAsync` 在成功插入或重复接收处理后 Touch。

- Legacy：`ClientId = "legacy:" + Normalize(AccessCode)`；AccessCode 来自项目接入码（与 `buildLicenseNo` 查库一致）。
- Modern：仅当 `SubmitMachineCode` 非空时 Touch；为空则跳过并可选 Debug 日志。

**理由**：Legacy 无 SignalR；用户约定 `legacy:{AccessCode}`。

**语义**：Legacy「在线」= 最近成功 Post 仍在 live TTL 内；超时无过磅 → 离线。

### D4: 客户端心跳 Out-of-Scope

**选择**：不实现 MaterialClient 周期 `RepublishCurrentStatuses`。

**理由**：升级代价高；Legacy 无收益。记入 backlog 供有 SignalR 客户端长期健壮性。

### D5: 验收

- SignalR：过期后再触发 UploadStatus（或 probe 扩展）→ client-list 恢复在线；既有 settle 仍过。
- Legacy：对已注册 AccessCode 成功 `/Api/Post` → client-list 含 `ClientId=legacy:{AccessCode}` 且 `isConnected=true`。
- L3：用户目视项目管理徽章。

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Legacy 同码多机合成一个实例 | 产品已接受 `legacy:{AccessCode}` |
| Modern Receive 无 SubmitMachineCode 不续期 | 文档；依赖 SignalR UploadStatus Touch |
| Urban 安静无上报仍假离线 | 接受本 change 边界；backlog 心跳或 Hub 映射续期 |
| 过磅把已关站标在线至 TTL | 无断连事件可清；TTL 自然掉；可接受业务活跃语义 |
| AccessCode 大小写/空格不一致 | Normalize：trim；大小写与 GovProject 查库策略一致 |

## Migration Plan

1. 发布 UM：Touch + UploadStatus + Receive/Legacy。
2. 验证 Urban SignalR 唤醒与 Legacy Post 在线。
3. 回滚：回退 UM 版本；无 DB migration；无客户端强制升级。

## Open Questions

- （非阻塞）Legacy live TTL 是否与 SignalR 共用公式，或单独更长——默认共用；现场过磅稀疏再调。
- （非阻塞）重复 Receive（去重更新）是否每次 Touch——建议 **是**（活跃证据）。
