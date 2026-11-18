## Context

`OnWeightAndStatusChanged` 在同一次回调中：

1. 若 `WaitingForStability → WeightStabilized` 且 `recordId == null` → `Enqueue(OnWeightStabilizedAsync)`（日志 status transition）
2. `ProcessStatusTransition` + `UpdateStatusAndNotify(WeightStabilized)`
3. 若 `WeightStabilized && IsStable && recordId == null` → **再** `Enqueue(OnWeightStabilizedAsync)`（日志 backup check）

若步骤 1 的任务尚未完成建单，`recordId` 仍为 null，步骤 3 就会再次入队。这是源码中明确存在的重复任务来源；发生与否取决于异步执行时序，不能据此认定所有现场双单均来自此路径。

调研：`docs/2026-11-17-weighing-stable-weight-carryover/02-根因与代码路径.md`。  
补充运行时复现方案：`docs/2026-11-17-weighing-stable-weight-carryover/05-FEV-同回调双入队复现.md` + Graph `pipelines/graphs/materialclient/fev-stable-dual-enqueue-repro/`。该文档当前仍为 `INCONCLUSIVE`（待 cook），没有已填实的运行身份，不作为已完成的真实进程复现证据。本 change 的局部修复以源码路径与确定性回归测试为依据，不以修复前 FEV 为实施前置条件。

当前组合流在调用处理器前使用 `.DistinctUntilChanged(t => t.Status)`。状态持续为 `WeightStabilized` 时，后续稳定采样不会再次触发该处理器。因此保留 backup 分支不等于提供持续采样重试能力。

## Goals / Non-Goals

**Goals:**

- 同一次 `OnWeightAndStatusChanged` 至多调度一次稳定建单。
- 保留处理器被实际调用时的 backup 条件分支，不保证持续稳定采样会再次调用处理器，也不保证失败任务自动重试。

**Non-Goals:**

- 不实现 `CreateWeighingRecordAsync` 的 `recordId` 防重（另 change）。
- 不引入周期版本号作废迟到任务（另 change）。
- 不改 `Merge(5)` 并发度、不改抓拍。
- 不改采样流的状态去重规则，不新增重试机制，不保证整个称重周期仅建一单。

## Decisions

### Decision 1: 用「本回调是否已入队建单」标志，而不是删掉 backup

在 `OnWeightAndStatusChanged` 开头设局部标志（如 `createScheduled = false`）。status-transition 调用 `EnqueueAsyncOperation` 后置 true；backup 条件增加 `!createScheduled`。该标志只表示本次回调已经请求调度，不表示异步建单成功；不引入跨回调共享状态。

采用局部标志，不改为 `previousStatus == WeightStabilized` 限制。后者会额外排除从其他状态进入 WeightStabilized 时原本可能执行的 backup 分支，超出本次仅消除同回调重复入队的范围。

**拒绝**：整段删除 backup — 在确认「状态已是 WeightStabilized 但从未入队」无真实缺口前过激（见调研 Q1）。

### Decision 2: 不在本 change 加 recordId 守卫

双入队是重复任务来源；建单入口防重是另一项保护。本 change 只去掉同回调双入队；入口防重留给后续 change。

### Decision 3: 复现单测改期望

将 `SingleStabilize_Reproduces_DoubleInsert_FromStatusAndBackupEnqueue` 重命名为回归用例。直接调用一次处理器，设置 WaitingForStability、稳定重量及空 recordId；使用可控的异步屏障暂停首次抓拍，使回调完成时 recordId 仍为空，再确认只有一次稳定抓拍入口。释放屏障并等待该建单任务完成后，断言恰好一次 Insert。不能只等到首次 Insert 就立即断言通过。

移除该用例辅助逻辑中「等待第二次稳定抓拍」的前提，避免修复后固定等待 3 秒。补充分支测试：已处于 WeightStabilized 且 recordId 为空时，显式调用处理器可调度一次 backup；已有 recordId 时不调度建单。这些测试不代表真实采样流会持续触发 backup。

`DelayedSecondCreate_AfterOffScale_Reproduces_ClosedOverWeightWithNextPlate` 的第二个任务依赖本次消除的双入队来源，不能原样保留为要求双单的测试。将其改为同一直接回调场景的回归：首次抓拍被屏障暂停、回调已返回时确认只有一个稳定任务；释放并等待首单完成，再驱动正常下磅与下一车牌输入（不触发下一次判稳），确认该回调没有第二个任务、没有沿用旧重量的新记录。不要把唯一的首单跨 ResetCycle 挂起后要求它失效；在途任务作废不在本 change 范围内。

`CreateWeighingRecordAsync_WhenRecordIdAlreadySet_StillInsertsAgain` 保留为已知缺陷的刻画测试，本次不将其改成入口防重断言。

## Risks / Trade-offs

- [Risk] 调度失败或建单失败后，持续稳定采样被状态去重过滤，不能依赖 backup 自动恢复。Accept：本次不新增恢复机制，运行时验收记录失败与缺单情况，另案处理。
- [Risk] 仅修双入队、无 Create 防重 → 其他路径仍可能双调 Create → Accept：本 change 范围声明清楚。  
- [Trade-off] 选用局部 bool 标志，仅限制本次回调内的重复调度，保留其他 backup 条件。

## Verification / Acceptance

- 实施验证：运行本测试类及 `AttendedWeighingSoundFireAndForgetTests`，证明同回调单次调度、backup 条件保留及状态播报路径无相关回归。
- 修复后运行时验收：在测试地磅环境记录代码基线、配置、操作步骤、日志和记录 ID；执行上磅判稳、正常下磅及下一车判稳，核对每次回调无双入队、重量与车牌对应、抓拍和下磅重置正常。该验证属于修复效果验收，不要求先运行修复前 FEV Graph，也不能使用以复现双单为通过条件的 Graph 作为修复通过标准。
- ICD 目标为 L2：本 change 声明的正常称重路径在目标环境可使用。未取得运行时证据前只能报告代码/测试完成，不能声称达到 L2；测试通过也不证明所有重复建单或迟到串牌均已解决。

## Migration Plan

1. 仅 MaterialClient 代码 + 测试；无 schema 迁移。  
2. 回滚：移除 backup 条件中的防重复入队检查即可。

## Open Questions

- 无。backup 是否长期保留（Q1）不阻塞本 change。
