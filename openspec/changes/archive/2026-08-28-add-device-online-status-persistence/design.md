## Context

当前两类状态都只在缓存：

1. **客户端长连接**：`ClientConnectionCacheItem`（多按 `ProId`），重启/TTL 后变「未注册」。
2. **设备类型详情**：`DeviceStatusCacheItem` 消息 FIFO，`GetClientDevicesAsync` 按 `DeviceType` 取最新；缓存空则设备弹窗无数据。`DeviceStatusLog` 实体存在但未进 DbContext。

前瞻：`docs/2026-08-25-urban-v2-four-machine-code-binding` — 同项目最多 4 机同时在线；`ClientId` = 机器码实例。禁止 ProId 单行连接态。

约束：AppService；`[UnitOfWork]`；命名 `record`；仅 UrbanManagement。

## Goals / Non-Goals

**Goals:**

- 连接态落库，唯一键 **`(ProId, ClientId)`**。
- **设备在线详情（当前态）**落库，唯一键 **`(ProId, ClientId, DeviceType)`**；`UploadStatus` 写库；`GetClientDevicesAsync` 读库。
- 断线：仅该实例连接态离线，并将其设备详情标 Offline。
- 项目管理：最后在线时间 + 客户端徽标聚合；设备弹窗展示落库详情。
- 缓存可写穿，非权威。

**Non-Goals:**

- 不实现 Urban V2 四槽授权 / Activate / F4。
- 不实现应用层心跳 / 萧山 `heatBeat`。
- **不**做设备状态全量历史审计表（append-only）；当前态 upsert 即可。可不启用旧 `DeviceStatusLog`。
- 不补写 `GovProject.LastSyncTime`。
- 不改 MaterialClient 上报协议。

## Decisions

### D1: `ClientOnlineStatus` — `(ProId, ClientId)`

- 字段：`ProId`、`ClientId`、`ProName`、`IsConnected`、`ConnectedAt`、`DisconnectedAt`、`LastSeenAt`；可选可空 `Slot`（本期不写）。
- 拒绝 ProId 唯一单行；拒绝塞进 `GovProject.MachineCode`。

### D2: `ClientDeviceOnlineStatus` — 设备详情当前态

- **选择**：新表/实体保存每个实例下每种 `DeviceType` 的**最新**状态（非 FIFO 日志）。
- 字段至少：`ProId`、`ClientId`、`DeviceType`、`Status`、`LastUpdateTime`、`AdditionalData?`；唯一 `(ProId, ClientId, DeviceType)`。
- **写**：`HandleStatusUploadAsync` / Hub `UploadStatus` 校验通过后 upsert。
- **断线**：将该 `(ProId, ClientId)` 下所有设备行 `Status=Offline` 并更新 `LastUpdateTime`（对齐现缓存行为），不影响其它 ClientId。
- **读**：`GetClientDevicesAsync(proId)` 从 DB 读；同 ProId 多实例时返回带 `ClientId` 的行（UI 可分组或平铺）；无行则空/「暂无设备数据」。
- **拒绝**：仅继续用 FIFO 缓存当详情源。
- **拒绝**：用未带 `ProId`、无当前态语义的旧 `DeviceStatusLog` 直接当详情表（若复用须改模型至与上等价；更推荐新实体以免与「日志」语义混淆）。

### D3: Hub 映射与断线按实例

- `ConnectionId → (ProId, ClientId)`；断线只动该实例的连接行 + 其设备详情行。

### D4: 项目级连接聚合（列表）

- 未注册 / 在线 / 离线 / 最后在线时间规则同前（对 `ClientOnlineStatus` 聚合）。设备详情不驱动列表徽标，只进弹窗。

### D5: 读路径 DB 权威

- `GetClientListAsync` ← 连接表；`GetClientDevicesAsync` ← 设备详情表。
- `ClientDeviceSummaryDto` MUST 能携带 `ClientId`（多机可区分）。

### D6: 缓存

- 设备 FIFO 缓存可保留写穿/广播加速；查询详情 MUST 回源 DB。
- 连接写穿键区分 `ClientId`。

### D7: 无心跳；时区统一写库时钟

- 同前。

## Risks / Trade-offs

- [UploadStatus 缺 ClientId/DeviceType] → 不落库对应详情；打日志；禁止 ProId-only 覆盖。
- [高频设备状态变更写库] → 当前态单行 upsert，成本可控；连接 `LastSeenAt` 仍可 ≥30s 节流。
- [弹窗多机数据变多] → DTO 含 ClientId；UI 可先平铺，V2 再按槽分组。
- [与四机授权并行] → 在线/设备表不替代槽位权威。

## Migration Plan

1. 两表 + 唯一索引 + migration。
2. 无缓存回填；再次 `UploadStatus`/连接后出现数据。
3. 回滚代码后表可留空。

## Open Questions

- 设备弹窗多 `ClientId` 时分组 UI 是否本期做 — **建议最小：列表含 ClientId 或分区标题；精致分组可二期**。
- 是否删除设备 FIFO 缓存 — 本期不强制，权威已在 DB。
