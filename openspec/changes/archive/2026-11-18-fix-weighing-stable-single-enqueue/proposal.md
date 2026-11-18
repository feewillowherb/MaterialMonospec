## Why

同一趟 `WaitingForStability → WeightStabilized` 回调里，`AttendedWeighingService.OnWeightAndStatusChanged` 会先走 status-transition 入队建单；若异步建单尚未设置 `recordId`，backup 就会再入队一次。两次任务都闭包同一吨数，再叠加异步延迟，可能落成同吨双单甚至串到下一车牌。

证据：`docs/2026-11-17-weighing-stable-weight-carryover/`；复现单测 `WeighingStableWeightCarryoverReproductionTests.SingleStabilize_Reproduces_DoubleInsert_FromStatusAndBackupEnqueue`。

关联真实进程 FEV 尚待执行，不作为已完成的复现证据，也不作为本次实施前置条件；本次以源码路径与确定性回归测试为依据，修复后仍需运行时验收。

## What Changes

- 同一次 `OnWeightAndStatusChanged` 调用中，**至多入队一次** `OnWeightStabilizedAsync`。
- status-transition 已入队建单时，同回调内的 backup **不得再入队**。
- 保留原 backup 条件，只增加本回调尚未调度建单的检查；现行状态去重会过滤持续稳定采样，不承诺后续采样自动补建。
- 将同回调双入队及依赖该任务来源的串牌用例改为确定性回归测试，保留无关的入口防重缺陷刻画测试。

## Capabilities

### New Capabilities

- （无）

### Modified Capabilities

- `attended-weighing`: 明确同帧 / 同回调仅一次稳定建单入队；backup 不得与 status-transition 叠加。

## Impact

- 子仓库：`MaterialClient`（`AttendedWeighingService`；`WeighingStableWeightCarryoverReproductionTests` 等）。
- 不在本 change 实现：`CreateWeighingRecordAsync` 的 `recordId` 守卫、周期版本号作废迟到任务（见调研夹后续项）。
- 不修改采样流去重规则，不新增自动重试；同回调单次入队不等于整个周期只建一单。
- 音响旁路已由 `fix-sound-fire-and-forget-offline-suppress` 处理，本 change 不重复。
