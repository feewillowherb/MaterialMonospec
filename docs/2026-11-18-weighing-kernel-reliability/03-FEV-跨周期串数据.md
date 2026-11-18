# 03 FEV — 在途稳定任务跨周期串数据

> 环：`Unknown → Experiment → Evidence → Verdict`  
> 本 FEV 只回答「当前基线上，唯一在途稳定建单能否串到下一周期」。  
> 不是修复方案可行性，不是 Capability 交付，不授权改产品行为。  
> 手段：现有测试宿主里的显式屏障。未启动 `MaterialClient`，未使用 Avalonia DevTools，未 cook。

## 1. 问题（Unknown）

唯一一次 `OnWeightStabilizedAsync` 已入队、尚未写完时，若下磅 `RewriteAndResetCycleAsync` 先清空周期，这次建单会不会：

1. 读到下一次识别的车牌或空的车辆信息；
2. 把本次记录 ID 写回已经重置的周期。

若两条都能在测试宿主里按固定时序出现，周期隔离就要进入后续设计。若不能，不得把「在途任务串周期」写成当前缺陷。

## 2. 实验（Experiment）

| 项 | 内容 |
|---|---|
| 环境 | `dotnet test`，类 `WeighingStableWeightCarryoverReproductionTests`。不启动桌面进程，不打开称重窗 |
| 基线 | `1d14322` `fix(attended-weighing): squash fix-weighing-stable-single-enqueue into main`。生产代码未改。证据来自该类新增的两个测试 |
| 时序 1 | 暂停第一次 `WeightStabilized` 抓拍；等下磅重置把车辆信息和车牌缓存清掉；再送入新车牌；然后释放抓拍 |
| 时序 2 | 在 `InsertAsync` 入口暂停（车牌和车辆信息已经读入局部变量）；同样等下磅重置完成并送入新车牌；然后释放插入 |
| 观察 | 插入行的重量、车牌、车辆颜色，以及重置后的 `recordId` 和当前车牌 |
| 判别 | 时序 1 若插入新车牌且重量仍是旧稳定重量，并写回 `recordId`，则「重置后才读取」成立。时序 2 若插入仍是旧车牌、当前车牌已是新车牌、`recordId` 仍写回，则「读取之后回写」成立 |

命令：

```powershell
dotnet test tests/MaterialClient.Common.Tests/MaterialClient.Common.Tests.csproj --filter "FullyQualifiedName~HeldCapture_OffScaleResetThenNewPlate|FullyQualifiedName~InsertHeld_OffScaleResetThenNewPlate"
```

工作目录：`repos/MaterialClient`。

## 3. 证据（Evidence）

| 字段 | 值 |
|---|---|
| 结果 | Passed 2 / Failed 0，约 2 秒。未启动客户端 |
| 时序 1 | 插入 1 行：重量 `8.815`，车牌为重置后的新车牌，车辆颜色为空，`recordId` 等于该行 |
| 时序 2 | 插入 1 行：重量 `8.815`，车牌和车辆颜色仍是重置前的值；释放后当前车牌已是新车牌，周期车辆信息为空，`recordId` 仍等于该行 |
| 生产入口 | `CreateWeighingRecordAsync` 的生产调用只有 `AttendedWeighingService.OnWeightStabilizedAsync` |
| 不含密钥 | 是 |

时序 1 说明建单在抓拍返回后读取实时车牌和车辆信息。时序 2 说明事务提交后的 `SetLastCreatedWeighingRecordId` 不核对周期是否还是入队时的那一次。两条都在 `Merge` 并发下发生，不依赖同回调双入队。

## 4. Verdict

| 问题 | Verdict |
|---|---|
| 在途唯一建单能否串到下一周期 | 测试宿主中成立。后续设计必须包含周期身份，以及提交前的数据归属 |
| 某一种修复（快照、丢弃、补存）是否可行 | `INCONCLUSIVE`。复现没有运行修复方案 |
| 现场发生频率 | `UNKNOWN`。本实验没有启动进程，也没有现场日志 |

`FEASIBLE` 不适用于尚未执行的修复。本结果也不是 ICD PASS。

## 5. 由此确定的推进

1. 不启动客户端，不用 Avalonia DevTools。激活码和 DevTools 授权都不在本实验里。
2. 周期隔离可以进入设计讨论。抓拍前、插入前、`recordId` 回写前都要能判断任务仍属于原周期；只在抓拍结束后查一次周期号覆盖不了时序 2。
3. 后续 Human 决策已记录在 [04-已确认业务决策.md](04-已确认业务决策.md)：允许舍弃迟到采集结果或形成不完整记录，禁止跨车借用数据，无图无牌不阻塞同步，并增加 ExtraProperties 诊断信息。该决定不改变本实验结果，也不代表修复方案已验证。
4. 失败停在哪一阶段、下磅失败是否污染下一周期，仍是 `PENDING_VALIDATION`。它们决定恢复语义，不推翻上面的周期隔离结论。
