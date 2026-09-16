# Tasks: add-urban-weighing-in-progress-sync-status

Mode A: baseline `main`. Change branch: `add-urban-weighing-in-progress-sync-status`（MaterialMonospec + MaterialClient + UrbanManagement）。

## 1. Branch

- [x] 1.1 三仓自 `main` 切出同名分支 `add-urban-weighing-in-progress-sync-status`

## 2. MaterialClient — Enum & create path

- [x] 2.1 `SyncStatus` 新增 `WeighingInProgress`（值 `3`，Description「称重中」）；列表/展示 switch 覆盖该值
- [x] 2.2 `UrbanWeighingExtension`：延迟建单初始 `WeighingInProgress`（`CreateWeighingInProgress` 或等价）
- [x] 2.3 `CreateForRecordAsync(evaluateAnomaly: false)` 写入 `WeighingInProgress` + deferred anomaly placeholder

## 3. MaterialClient — Promote to Pending

- [x] 3.1 下磅/周期结束侧效应：对 `WeighingInProgress` 正式评估异常后置 `Pending`
- [x] 3.2 `RecalculateAnomalyAfterLprOrCycleAsync`：更新异常；保持 `WeighingInProgress` 直至下磅；若已 `Synced`/`Failed` 且异常有变化则打回 `Pending`
- [x] 3.3 人工编辑路径保持评估 + `Pending`；即时审批上传前若仍为 `WeighingInProgress` 则先评估并提升再传

## 4. MaterialClient — Polling & tests

- [x] 4.1 确认 `GetPendingForUploadAsync` 仅 `Pending`（不含 `WeighingInProgress`）
- [x] 4.2 单测：建单为称重中、下磅提升 Pending、称重中不入上传队列、Synced 后异常变化重回 Pending
- [x] 4.3 MaterialClient 相关 `dotnet test` 通过

## 5. UrbanManagement — Empty-plate fallback

- [x] 5.1 Receive 映射（`FromReceive` / `ApplyDuplicateReceive` 或紧邻逻辑）对空/空白 `PlateNumber` 强制 `IsAnomaly=true` 与空车牌原因文案
- [x] 5.2 有车牌时仍信任客户端 `IsAnomaly`；不引入重量阈值重算
- [x] 5.3 UM 单测：空车牌 + `isAnomaly:false` → 异常；有车牌 + false → 正常；重复接收空车牌不可洗白

## 6. Verify

- [x] 6.1 三仓相关测试通过；勾选本 tasks
