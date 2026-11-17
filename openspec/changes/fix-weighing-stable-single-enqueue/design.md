## Context

`OnWeightAndStatusChanged` 在同一次回调中：

1. 若 `WaitingForStability → WeightStabilized` 且 `recordId == null` → `Enqueue(OnWeightStabilizedAsync)`（日志 status transition）
2. `ProcessStatusTransition` + `UpdateStatusAndNotify(WeightStabilized)`
3. 若 `WeightStabilized && IsStable && recordId == null` → **再** `Enqueue(OnWeightStabilizedAsync)`（日志 backup check）

步骤 1 的任务尚未执行，`recordId` 仍为 null，故步骤 3 几乎总会再入队。现场同吨双单的主任务源即此。

调研：`docs/2026-11-17-weighing-stable-weight-carryover/02-根因与代码路径.md`。  
FEV 复现：`docs/2026-11-17-weighing-stable-weight-carryover/05-FEV-同回调双入队复现.md` + Graph `pipelines/graphs/materialclient/fev-stable-dual-enqueue-repro/`（真实进程诊断 API；同回调双日志 + 同吨 ≥2 行）。`FEASIBLE` 不是已 apply。

## Goals / Non-Goals

**Goals:**

- 同一次 `OnWeightAndStatusChanged` 至多调度一次稳定建单。
- 保留「已处于 WeightStabilized、此前入队丢失/未跑」时 backup 补一次的能力（跨回调，而非同回调叠加）。

**Non-Goals:**

- 不实现 `CreateWeighingRecordAsync` 的 `recordId` 防重（另 change）。
- 不引入周期版本号作废迟到任务（另 change）。
- 不改 `Merge(5)` 并发度、不改抓拍。

## Decisions

### Decision 1: 用「本回调是否已入队建单」门闩，而不是删掉 backup

在 `OnWeightAndStatusChanged` 开头设局部标志（如 `createScheduled`）。status-transition 入队成功后置 true；backup 条件增加 `!createScheduled`。

等价写法（也可接受）：backup 仅在 `previousStatus == WeightStabilized`（本回调无状态迁移）时运行。门闩法更直接表达「同回调不二次入队」，且覆盖「本回调有迁移但未入队（例如已有 recordId）」时 backup 仍不误伤的情况——若 transition 因已有 recordId 未入队，backup 同样因 recordId 非 null 跳过，行为一致。

**拒绝**：整段删除 backup — 在确认「状态已是 WeightStabilized 但从未入队」无真实缺口前过激（见调研 Q1）。

### Decision 2: 不在本 change 加 recordId 守卫

双入队是双任务源；防重是第二道闸。用户本轮只要去掉同帧双入队；守卫留给 `fix-weighing-stable-create-once` 类 change，避免范围膨胀。

### Decision 3: 复现单测改期望

`SingleStabilize_Reproduces_DoubleInsert_FromStatusAndBackupEnqueue` 改为断言一次判稳仅 1 次 `Insert`（或重命名为回归用例）。其余「无守卫 / OffScale 迟到」用例若仍断言缺陷行为，可保留到后续 change，或仅改双入队相关用例——tasks 中明确只改双入队断言。

## Risks / Trade-offs

- [Risk] 若 status-transition 入队后任务丢失且同周期不再有稳定采样 → backup 可能补不上 → Mitigation：后续采样在已是 WeightStabilized 时仍可走 backup（跨回调）。  
- [Risk] 仅修双入队、无 Create 防重 → 其他路径仍可能双调 Create → Accept：本 change 范围声明清楚。  
- [Trade-off] 局部 bool 门闩 vs 「仅 previous==WeightStabilized」：选用门闩，语义贴「同回调」。

## Migration Plan

1. 仅 MaterialClient 代码 + 测试；无 schema 迁移。  
2. 回滚：恢复 backup 无门闩即可。

## Open Questions

- 无。backup 是否长期保留（Q1）不阻塞本 change。
