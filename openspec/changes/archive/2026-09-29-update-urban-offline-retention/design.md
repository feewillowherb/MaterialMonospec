## Context

`fix-urban-signalr-disconnect-storm` 已将 SignalR 热路径改为只写 Redis，消除断连打 SQLite 的卡顿。现场反馈：断连后徽章很快变成「未注册」（短 TTL），且 Redis 不可用/清空后无法保留离线壳。产品要求 **离线保留一周**，并 **每天把缓存状态刷到 EF**；查询在 Redis miss 时可回源。

## Goals / Non-Goals

**Goals:**

- 离线连接条目 Redis TTL 默认 **7 天**（可配置）；在线仍用短 live TTL
- connection registry 保留期覆盖离线 TTL
- 每日一次后台任务：Redis 快照 → upsert `ClientOnlineStatus`（及约定的设备当前态，若本 change 纳入）
- 管理页连接查询：**Redis 优先**；miss 时回源 EF 已登记行并按 **离线** 参与聚合（防幽灵在线）
- Hub connect / disconnect / `UploadStatus` **继续零 EF**

**Non-Goals:**

- 恢复热路径 EF upsert
- SignalR Redis 背板
- 实时双写或秒级刷库
- MaterialClient 协议变更
- 归档/合并 `fix-urban-signalr-disconnect-storm`（可并行；本 change 叠在其语义之上）

## Decisions

### D1: 在线短 TTL / 离线长 TTL

**选择**：`UpsertClientConnectedAsync` / `UploadStatus` 续期 → live TTL（≥ 2× `ClientTimeoutInterval`）。`UpsertClientDisconnectedAsync` → `IsConnected=false` + TTL = `OfflineRetentionDays`（默认 7）。不断连删键。

**理由**：短 TTL 防幽灵在线；长 TTL 保住「离线」徽章。

### D2: Registry 与离线对齐

**选择**：更新 connection registry 时使用不少于离线保留期的 TTL，避免 registry 先过期导致离线键扫不到。

### D3: 日批刷 EF（非热路径）

**选择**：ABP `BackgroundWorker`（或等价），默认约 **24h** 周期；读取 Redis 连接 registry + connection payloads，upsert `ClientOnlineStatus`。可选同步设备当前态到 `ClientDeviceOnlineStatus`（tasks 标明是否本 change 必做；默认 **连接表必做，设备表建议做**）。独立 UoW，失败可观测、不拖垮 Hub。

**否决**：断连队列刷库（易在风暴时再打 SQLite）。

### D4: 查询 Redis → EF 回源（离线壳）

**选择**：`GetLiveClientConnectionsAsync`（或聚合入口）：

1. 收集 Redis 命中条目（在线/离线原样）
2. 对 Redis 未覆盖的 `(ProId, ClientId)`，若 EF 有行 → 映射为 **离线** DTO（展示用 `IsConnected=false`，保留 `LastSeenAt`/`DisconnectedAt`）
3. 聚合规则不变：有在线→在线；仅离线→离线；皆无→未注册

**理由**：日批才有价值；EF 的 `IsConnected=true` 在 Redis miss 时不得直接当在线，避免幽灵在线。

### D5: 配置

`SignalR:OfflineRetentionDays`（默认 7）；日批周期可配置（默认 24h）。密码等 Redis 连接串不进本 change 范围以外的提交约定。

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| 日批间隔内 Redis flush → EF 最多旧一天 | 可接受；徽章靠 EF 离线壳；客户端重连写回 Redis |
| Registry 脏键堆积 | 查询跳过 null；可选读时清理；LRU + 7 天上限 |
| 设备弹窗仍可能 Redis miss 为空 | 若同步设备表则同样 miss 回源；否则本 change 优先保证连接徽章 |
| 与 storm-fix「禁止回源」冲突 | 本 change **MODIFIED** 相关 spec，显式取代 |

## Migration Plan

1. 部署 UM：新 TTL + 查询回源 + Worker
2. 无需 migration（表已存在）
3. 回滚：关掉 Worker、恢复短 TTL、去掉 EF 回源（徽章行为回到 storm-fix）

## Open Questions

- 无（设备表是否日批：默认纳入连接+设备当前态快照，实现若工期紧可 tasks 拆「连接必做 / 设备可选」）
