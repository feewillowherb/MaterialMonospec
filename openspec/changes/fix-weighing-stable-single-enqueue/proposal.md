## Why

同一趟 `WaitingForStability → WeightStabilized` 回调里，`AttendedWeighingService.OnWeightAndStatusChanged` 会先走 status-transition 入队建单，再走 backup 再入队一次（此时 `recordId` 仍为 null）。两次任务都闭包同一吨数，再叠加异步延迟，会落成同吨双单甚至串到下一车牌。

证据：`docs/2026-11-17-weighing-stable-weight-carryover/`；复现单测 `WeighingStableWeightCarryoverReproductionTests.SingleStabilize_Reproduces_DoubleInsert_FromStatusAndBackupEnqueue`。

## What Changes

- 同一次 `OnWeightAndStatusChanged` 调用中，**至多入队一次** `OnWeightStabilizedAsync`。
- status-transition 已入队建单时，同回调内的 backup **不得再入队**。
- backup 仅保留「已经是 WeightStabilized、本回调没有刚做 transition 建单入队，且仍无 recordId」的补建语义。
- 更新相关复现单测：一次判稳期望仅 1 次 `Insert`（针对双入队路径）。

## Capabilities

### New Capabilities

- （无）

### Modified Capabilities

- `attended-weighing`: 明确同帧 / 同回调仅一次稳定建单入队；backup 不得与 status-transition 叠加。

## Impact

- 子仓库：`MaterialClient`（`AttendedWeighingService`；`WeighingStableWeightCarryoverReproductionTests` 等）。
- 不在本 change 实现：`CreateWeighingRecordAsync` 的 `recordId` 守卫、周期版本号作废迟到任务（见调研夹后续项）。
- 音响旁路已由 `fix-sound-fire-and-forget-offline-suppress` 处理，本 change 不重复。
