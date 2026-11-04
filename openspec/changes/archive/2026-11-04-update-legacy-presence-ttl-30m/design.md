## Context

- Legacy 无 SignalR 客户端经 `/Api/Post` → `ReceiveAsync` → `TouchOnlineAsync`，`ClientId = legacy:{AccessCode}`（已落地）。
- 当前 live Redis TTL = `max(60, ClientTimeoutIntervalSeconds) × 2`（默认约 120s），与 SignalR 共用。
- 过磅间隔通常大于 2 分钟 → 管理端徽章几乎总是离线。用户要求 Legacy 业务活跃窗口先定为 **0.5 小时（30 分钟）**。

## Goals / Non-Goals

**Goals:**

- `legacy:` 前缀的 live `ClientConnection` 写入使用 **30 分钟** AbsoluteExpiration。
- SignalR / 非 `legacy:` ClientId 继续用现有短 live TTL。
- 配置可声明该窗口（默认 30 分钟），避免魔法数散落。

**Non-Goals:**

- Hub 连接图定时续期、MaterialClient 周期心跳。
- 加长全局 SignalR live TTL。
- 改变 EF Redis-miss 强制离线、`legacy:{AccessCode}` 约定、OfflineRetentionDays。
- 迁移后未再 Post 的历史「在线」自动复活。

## Decisions

### D1: 按 ClientId 前缀选择 live TTL

**选择**：在 `DeviceStatusService` 写 live connection（`SetConnectionCacheAsync` / `TouchOnline` / `UpsertClientConnected` 的 live 路径）时，若 `ClientId` 以 `legacy:` 开头（OrdinalIgnoreCase），使用 Legacy live TTL；否则用现有 `GetLiveTtl()`。

**理由**：Receive 与任何将来写入 `legacy:` 的路径自动受益；不改 Hub 协议。

**备选否决**：仅在 `TouchPresenceFromReceiveAsync` 旁路设 TTL（易漏其它入口）；全局改 `GetLiveTtl()`（拖长 SignalR 幽灵在线）。

### D2: 默认 30 分钟，可配置

**选择**：在 `SignalROptions`（或并列 `ClientPresenceOptions`）增加 `LegacyLiveTtlMinutes`，默认 `30`；`Math.Max(1, value)` 防误配为 0。本 change 产品值固定为 0.5h。

**理由**：部署可调；默认即用户要求。

### D3: 仅 connection live 键；设备详情键不强制跟 30 分钟

**选择**：本 change 只延长 **ClientConnection** live TTL。Device status cache 仍用现有 live/offline 策略（Legacy Post 本就不写设备详情 Redis）。

**理由**：徽章在线来自 connection 聚合；缩小范围。

### D4: Registry 续期

**选择**：`UpdateConnectionRegistryAsync` 可继续用 offlineRetention（长保留）或与现网一致；不因本 change 缩短 registry。Legacy connection 条目本身带 30 分钟 TTL。

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| 关站后最长约 30 分钟仍显示在线 | 产品接受的业务活跃语义；无 SignalR 断连事件 |
| 与 SignalR 同 ProId 多实例并存 | 已有 `(ProId, ClientId)` 聚合；`legacy:` 与机器名并存 |
| 未 Post 的站点仍全离线 | 文档说明；下次成功 Post 后亮 30 分钟 |
| 配置单位混淆（秒/分） | 属性名 `LegacyLiveTtlMinutes`；测试锁定 30 |

## Migration Plan

1. 发布 UrbanManagement（含 ingest/realtime 等共用 Core）。
2. 手测或采证：成功 Legacy Post → client-list 中 `legacy:{AccessCode}` `isConnected=true`，Redis TTL ≈ 1800s。
3. 回滚：回退版本或将 `LegacyLiveTtlMinutes` 调回接近原短 TTL（不推荐作长期）；无 DB migration。

## Open Questions

- 无（0.5h 已由用户确认）。SignalR Hub 续期另开 change。
