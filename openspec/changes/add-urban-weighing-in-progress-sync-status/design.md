## Context

Urban 客户端在重量稳定时创建 `UrbanWeighingExtension`，当前固定 `SyncStatus.Pending` + 延迟异常占位（`IsAnomaly=false`）。`PollingBackgroundService` 只上传 `Pending`，因此稳定后、下磅前即可把占位「正常」打到 UM。正式异常回写（`RecalculateAnomalyAfterLprOrCycleAsync`）只改 `IsAnomaly`，不重回 `Pending`，若已 `Synced` 则 UM 与客户端永久分叉。

约束：Mode A；`minimal-di`；禁止 tuple；`SyncStatus` 为 MaterialClient 共享枚举（`Pending`/`Synced`/`Failed`），与 UM 政府同步枚举（`Pending`/`Success`/`Failed`）分离。既有 `urban-weighing-api` 要求 Receive 不按阈值重算异常——本 change 仅增加**空车牌**窄例外兜底。

## Goals / Non-Goals

**Goals:**

- 引入 `SyncStatus.WeighingInProgress`，稳定建单时使用，**禁止上云**。
- 周期就绪并完成正式异常评估后提升为 `Pending`，再走既有轮询。
- 既有 `Pending` 未同步行保持可上传；不做数据回填为称重中。
- 异常回写与同步态协同，避免占位正常固化后无法重传。
- **UM 兜底**：Receive 时车牌为空则强制异常（不依赖客户端是否已回写）。

**Non-Goals:**

- 不在 UM 增加「称重中」业务态或审批流。
- 不改 Passage 上传状态机。
- 不改为独立 bool 字段 `WeighingInProgress`。
- 不在本 change 处理「异常是否仍跳过上传」历史注释——保持现状：`Pending` 即可上传（含异常）。
- **不**在 UM 重跑重量上下限 / 偏差百分比规则；**不**在 UM 做抓拍附件缺失判定（仍以客户端为准，除非另开 change）。

## Decisions

### D1 — 扩展 `SyncStatus` 枚举，不加新列

**Decision：** 新增 `WeighingInProgress`（建议值 `3`，`[Description("称重中")]`）。SQLite 仍存 int；无 EF migration 列变更。

**Alternatives：** 独立 bool 字段 — 与 `SyncStatus` 双源；否决。上传门禁但不改枚举 — 更小补丁但语义不清晰；用户明确要求 WeighingInProgress 方案。

### D2 — 建单初值 = WeighingInProgress + 延迟异常占位

**Decision：** `AfterWeighingRecordCreatedAsync` / `CreateForRecordAsync`（`evaluateAnomaly: false`）创建时：`SyncStatus = WeighingInProgress`，并继续 `ApplyDeferredAnomalyPlaceholder()`。

**Alternatives：** 建单仍 Pending — 无法挡住轮询；否决。

### D3 — 提升为 Pending 的触发点

**Decision：** 下列任一发生时，在完成正式异常评估（或确认已评估）后将扩展提升为 `Pending`（若当前为 `WeighingInProgress`）：

1. **下磅完成**（`WaitingForDeparture` → `OffScale` 或等价周期结束侧效应）— 主路径，保证「车已下磅才允许排队上云」。
2. **`RecalculateAnomalyAfterLprOrCycleAsync`** — 更新异常后：若仍为 `WeighingInProgress` **保持**称重中（不下磅不上传）；若已是 `Synced`/`Failed` 且异常状态相对上传有变化，则打回 `Pending`（与编辑路径对齐，修复已错传正常的记录）。
3. **人工编辑** — 沿用现有 `AfterWeighingRecordEditedAsync`：评估异常 + `Pending`。

下磅路径若尚未做过正式评估，MUST 在此评估一次再置 `Pending`。

**Alternatives：** 异常回写即 Pending（车仍在磅可上传）— 与「下磅前不上云」目标冲突；否决为默认。仅 OffScale、忽略已 Synced 错传 — 无法修复历史分叉；否决。

### D4 — 轮询与即时上传

**Decision：** `GetPendingForUploadAsync` 继续 **仅** `SyncStatus == Pending`。`WeighingInProgress` 不得入队。审批触发的 `UrbanWeighingUploadRequested` 即时上传前，若仍为 `WeighingInProgress`，MUST 先正式评估并提升为 `Pending`（实现选「先提升再传」）。

### D5 — UM 空车牌兜底（新增）

**Decision：** 在 `UrbanWeighingRecord.FromReceive` / `ApplyDuplicateReceive`（或 `ReceiveAsync` 紧邻映射之后）应用：

- 若 `string.IsNullOrWhiteSpace(PlateNumber)` → `IsAnomaly = true`，`AnomalyReason` 设为与客户端空车牌一致的文案（如「车牌为空」；优先复用/对齐既有常量若存在）。
- 若车牌非空：保留客户端上报的 `IsAnomaly` / `AnomalyReason`（含客户端上报 true、审批后 false 的重复接收）。
- **禁止**在此路径调用重量上下限 / 偏差检测。

**Rationale：** 客户端 `WeighingInProgress` 挡早传；UM 兜底挡「已错传正常 / 旧客户端 / 竞态漏网」的空车牌显示为正常。

**Alternatives：** 仅客户端修复 — 用户要求服务端兜底。全量服务端重算异常 — 与 urban-anomaly-client-only 冲突过大；否决。

### D6 — 展示

**Decision：** 客户端列表对 `WeighingInProgress` 显示「称重中」。UM 徽章仍看 `IsAnomaly`（兜底后空车牌为异常）。

## Risks / Trade-offs

- [Risk] 下磅侧效应遗漏 → 永远卡在称重中 → Mitigation：单测 OffScale 提升；日志。
- [Risk / Known] 进程在称重中关闭或崩溃 → 本地扩展仍在 SQLite（不丢数据），但状态可长期停在 `WeighingInProgress`、不上云。Mitigation（本 change）：仅靠再次 OffScale / `EnsureReadyForUploadAsync` / 人工编辑提升；**不做**启动扫描或超龄自动提升（已在 proposal「Known limitation」标记；补救另开 change）。
- [Risk] 重复 Receive 客户端带空车牌 + `IsAnomaly=false` 试图「洗白」 → Mitigation：兜底强制异常，不允许空车牌正常。
- [Risk] 车牌占位符（如「无」「未识别」）是否算空 → Mitigation：本 change **仅** `IsNullOrWhiteSpace`；字面「无」另议，不纳入本兜底 unless 与客户端 EmptyPlate 规则对齐后在 tasks 注明。

## Migration Plan

1. 先发或同发 UM 兜底 + 客户端 WeighingInProgress（可先发 UM，立即修复历史错显；客户端减少早传）。
2. 旧客户端 `Pending` 行继续上传；空车牌被 UM 标异常。
3. Rollback：回退两端二进制；枚举值 3 残留见前。

## Open Questions

- 字面「无」是否视为空车牌：默认否，仅 whitespace（无阻塞）。
- **Follow-up（已知、非本 change）**：`WeighingInProgress` 残留行在进程重启后是否做启动扫描 / 超龄自动提升为 `Pending`？默认否；见 proposal Known limitation。
