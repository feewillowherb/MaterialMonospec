# 00 · FEV：MaterialClient SQLite 写入冲突

- **日期**：2026-11-24
- **范围**：MaterialClient SolidWaste 有人值守称重；稳定后 `WeighingRecord` 写入失败
- **生命周期**：`ACTIVE`
- **研究状态**：`INCONCLUSIVE`
- **FEV Verdict**：`INCONCLUSIVE`

## 可行性问题

稳定判定已成立时，`SQLite Error 5: database is locked` 是否由称重状态机未判稳造成？若不是，现有证据能否确定具体竞争写入方，并验证写入串行化或重试方案足以消除此类建单失败？

本 FEV 只调查当前证据及最小验证路线，不修改产品代码、不创建 OpenSpec change。FEV 结论不代表 Capability 已交付。

## Unknown

需要区分：

1. 状态机是否没有到达稳定状态。
2. 称重记录是否在稳定后尝试写库但被并发事务挡住。
3. 哪个连接 / 进程 / UoW 持有冲突锁；现有日志是否足以验证修复路线。

## Experiment

### 输入

- 现场日志快照：`_tmp/1124/MaterialClient.SolidWaste-20261124.log`。
- 当前源码：`repos/MaterialClient/`，本次调查工作区 `MaterialClient` HEAD 为 `72f46076`（`fix(solidwaste): squash fix-solidwaste-weighing-detail-load into main`）。
- 对照已有知识：[`2026-08-28-materialclient-product-ef-isolation/03-同库双Context设置保存锁.md`](../../2026-08-28-materialclient-product-ef-isolation/03-同库双Context设置保存锁.md) 与 [`2026-11-18-weighing-kernel-reliability/00-调研总览.md`](../../2026-11-18-weighing-kernel-reliability/00-调研总览.md)。

### 操作

1. 将用户报告的六个稳定时刻前后日志按时间排列，核对 `IsStable`、DB 保存异常、周期建单错误和最终状态。
2. 对照异常调用栈，定位失败是在产品副作用之前还是之后，以及失败发生在哪个 DbContext / Repository 操作。
3. 搜索同一日志中的其它 SQLite 写失败，检查是否有不同写入路径也受锁影响。
4. 静态检查数据库配置和周期后台任务，确认是否定义了写入串行化、显式锁等待参数，以及并发 UoW 的存在。

本次未获得现场 SQLite 数据库、进程清单或锁持有者采样；未运行设备或复现写入竞争。

## Evidence

### 已确认：稳定检测成功，记录写入失败

六个用户给定时段均反复记录 `stability.IsStable=true`，之后在 `MaterialClientDbContext.SaveChangesAsync` 过程中出现 `SQLite Error 5`，再由 `WeighingRecordService.CreateForCycleAsync` 记录周期建单异常：

| 稳定时段 | 稳定重量（日志值） | EF 保存错误 | 周期建单错误 |
|---|---:|---:|---:|
| 12:03 | 10.950t | 12:03:30.132，行 34608–34628 | 12:03:31.133，行 34650 |
| 12:14 | 13.920t | 12:14:12.812，行 35245–35265 | 12:14:13.710，行 35287 |
| 12:15 | 13.910t | 12:15:21.627，行 35402–35422 | 12:15:22.717，行 35444 |
| 13:05 | 4.840t | 13:05:46.395，行 37192–37212 | 13:05:47.398，行 37234 |
| 13:07 | 4.850t | 13:07:00.046，行 37367–37387 | 13:07:01.148，行 37409 |
| 13:15 | 70.410t | 13:15:29.735，行 37812–37832 | 13:15:30.644，行 37854 |

调用栈落在 `WeighingRecordService.CreateForCycleAsync` 的 `InsertAsync(weighingRecord, autoSave: true)`，经 EF 保存内核 `MaterialClientDbContext` 时失败。代码位置：`repos/MaterialClient/src/MaterialClient.Common/Services/AttendedWeighing/WeighingRecordService.cs`，建单从第 145 行开始，插入在第 197 行。

每次建单异常后仍有 `Entered WeightStabilized state` 和“称重已结束”语音日志。当前实现 catch 后将周期标为 `Failed` 并记录错误（同文件第 243–244 行）；状态日志不是记录已落库的证据。

### 已确认：并非只在稳定建单路径遇到锁

同一日志还记录：

- 08:28：`TryMatchEventHandler.HandleEventAsync` 的数据库保存失败，行 22611–22648。
- 09:59、10:20、10:41：另有三次周期建单异常，行 27115–27158、30276–30316、32546–32589。
- 12:10：`MarkRecoveryCompletedAsync` 更新记录失败，行 34960–34997。
- 12:12：`PollingBackgroundService` 的 UoW 提交失败，行 35146–35171。
- 12:42：轮询后台任务提交也失败，行 36521–36558。

因此本日志内最早已于 08:28 出现锁冲突，全天至少九次 `CreateForCycleAsync` 建单错误；不是只在用户指出的六个时间点发生。不同写路径的失败支持“SQLite 写入竞争”这一类根因，但不能证明它们由同一个锁持有者造成。

### 源码检查

- `repos/MaterialClient/src/MaterialClient.Common.EntityFrameworkCore/MaterialClientSqliteDbContextOptions.cs` 只配置 `UseSqlite`、migration history table 与 EF 详细日志；没有看到应用显式配置 WAL、写入队列或针对 SQLITE_BUSY 的重试策略。未据此推断 SQLite provider 的默认 timeout 值。
- `repos/MaterialClient/src/MaterialClient.Desktop.Hosting/Backgrounds/PollingBackgroundService.cs` 每 10 分钟运行一轮；多个同步动作各自通过 `WithUow` 建立并提交 UoW（第 26–28、43–58、71–80 行）。这是一个并发写入来源候选，但日志中的 12:12 轮询失败与用户列出的六次建单时刻均没有证据证明事务重叠，不能指认为直接肇因。
- `WeighingRecordService` 的初始内核记录插入在后续 `AfterWeighingRecordCreatedAsync` 产品副作用之前；六次栈均指向该初始 `InsertAsync`。因此不能把这六次失败简单归结为“同一建单 UoW 随后写 SolidWaste 扩展”的跨 Context 组合写。
- 2026-08-28 已有 Urban 设置保存的 SQLITE_BUSY 事故，其根因是同一 UoW 中对同一文件开启第二个 Context 写事务；它证明本项目曾出现锁问题，但属于不同调用路径，不能直接当作本次根因证据。

## Verdict — `INCONCLUSIVE`

**已证实的近因**：稳定后写入 `WeighingRecord` 时 SQLite 返回 `database is locked`，使周期建单进入失败路径；这解释了记录列表缺项。

**尚未证实的根因**：持锁者可能来自应用内另一条 UoW / 数据库更新路径，也可能来自同一 SQLite 文件的其它进程。日志没有 DbConnection 标识、数据库绝对路径、进程 PID、事务开始 / 提交区间或 SQLITE_BUSY 等待耗时；目前无法判断竞争来自哪一条路径，也无法排除现场数据库被其他进程打开。

**路线判断**：增加 busy retry 或 WAL 单独使用都不足以证明能解决问题；WAL 也不允许多个写事务同时执行。应先取得能关联到同一 DB 文件和事务区间的诊断证据，再评估串行化 / 缩短 UoW / 有界重试的组合。当前证据不支持 `FEASIBLE` 或 `INFEASIBLE` 的修复 Verdict。

## 最小下一步实验

在可控测试环境用相同 SQLite provider 与当前 SolidWaste 配置，给所有数据库写入入口记录 `ProcessId`、DB 文件规范路径（脱敏）、Context 类型、UoW / 操作名、事务开始与结束时间，并统计 SQLITE_BUSY 等待时长；对“后台轮询提交与稳定建单重叠”进行一次可控对照，观察失败是否可重复、串行化后是否消失。必须保留失败轨迹；仅增加 timeout 后不再看到错误，不足以证明锁源已消除。

若无法复现或覆盖所有数据库连接者，应保持 `INCONCLUSIVE`。产品行为变更另需 Human `APPROVED` 和 OpenSpec change。

## Pipeline 复现能力评估

检查了 `pipelines/graphs/materialclient/` 的 active Graph，原有 Graph 没有针对 `materialclient-sqlite-write-contention-fev` goal 的匹配能力。现已生成独立 Graph：[`fev-sqlite-write-contention-repro`](../../pipelines/graphs/materialclient/fev-sqlite-write-contention-repro/pipeline.md)。

| Graph | 现有能力 | 对本问题的缺口 |
|---|---|---|
| `fev-stable-dual-enqueue-repro`（probe） | 通过诊断 API 注入测试车牌 / 重量，在运行客户端里观察稳定建单及 SQLite 行 | 只验证双入队重复建单，不注入第二个持锁事务 |
| `urban-busy-weighing-sim`（transform） | `net10.0` 脚本重放稳定称重规则 | 不启动 MaterialClient、不访问 SQLite，也不属于 probe goal |
| `materialclient-working-db-load`（probe） | 用 working DB 启动客户端并扫描本次日志 | 不并发持锁、不注入称重事件 |

**结论**：Pipeline 技术上可以构造可控复现。新 Graph 只对一次性工作库副本运行，以 MaterialClient 诊断 API 触发稳定建单，同时由 Graph 的 .NET 10 实验进程通过 `Microsoft.Data.Sqlite` 在同一工作库短暂持有写事务；采集应用日志和工作库变化，判定应用是否走到 `CreateForCycleAsync` 并返回 SQLITE_BUSY。Graph 无 `ProjectReference` 产品项目，仅通过 API 与 SQLite 文件实验交互。

该实验只能证明“外部竞争写事务能否令当前应用建单失败”以及 Graph 能否稳定采到该失败；它**不能**单独证明现场实际锁持有者是外部进程，也不能验证应用内部 UoW 竞争来源。要确认现场根因，仍需为产品增加或启用事务 / 进程诊断，再在隔离测试库中对内部候选路径做并发对照。

### 修复版复测

- Run `fev-sqlite-write-contention-repro/2026-11-24T155703` 使用 MaterialClient `6f98a6e6` 构建产物。进程连接升级后的本地工作库副本，运行中的客户端通过 Graph 的 API 探针注入数据。
- 外部事务持锁 45 秒。15:57:22 确认重量 10.950t 已判稳，15:57:52 建单返回 `SQLITE_BUSY`。测试车牌对应记录数为 0 → 0，持锁事务已释放。
- P0–P2 证据齐备，Graph 结果为 `pass`，表示修复版仍可复现**外部持锁导致建单失败**。进程内写入竞争和历史现场持锁方仍待验证。P3 由用户判定。

## 阅读路径

### 不注入外部锁的十周期对照

- Run `fev-solidwaste-ten-weighing-cycles/2026-11-24T161227` 在固废修复版 `6f98a6e6` 上完成 10 次上磅、判稳与下磅。32 个 API 请求均返回 HTTP 200。10 个不同 CycleId 各有一条固废记录，车牌与重量匹配，观察窗未出现 SQLite 锁错误。
- Graph 结果为 `pass`，P0–P2 达成。该 Run 覆盖日常称重路径的十次样本。指定后台写入与建单恰好重叠时的表现仍待验证。

### 不注入外部锁的百周期短间隔验证

- Run `fev-solidwaste-ten-weighing-cycles/2026-11-24T161700` 使用固废修复版 `6f98a6e6`，以 `-Cycles 100 -Fast` 运行。每次确认离磅后开始下一周期，额外等待为 0 毫秒。
- 100 次下磅均有日志，100 个不同 CycleId 各落库一条正确的固废记录，302 个 API 请求均为 HTTP 200，观察窗内无 SQLite 锁错误。相邻下磅平均间隔 7.67 秒，最短 7.59 秒，最长 8.01 秒。
- Graph 结果为 `pass`，P0–P2 达成。结果覆盖实际运行的短间隔场景，未控制指定后台事务和称重写入的重叠时机。

- [SQLite 写锁修复方案](01-SQLite写锁修复方案.md)整理进程内串行化、短事务、有界恢复及部署互斥的适用范围和验证顺序。

### 现场日志复查

- 08:27:53 内核建单成功（19679）。08:28:07 自动匹配在 `CopyMatchedFieldsAsync` 查询扩展表时返回 SQLite Error 1（缺少 `SolidWasteWeighingExtensions`）。约 9 ms 后，内核的恢复完成标记写入报 Error 5（日志 22520、22583、22611、22648）。这是相邻的两个故障，时间接近不能确定谁持锁。
- 12:03 的失败发生在初始内核建单的 EF 写入批次处理内，12:05:34 又成功建单（19701）。12:14 和 12:15 失败后，12:16:34 再次成功（19703）。这些成功记录表明故障间歇出现。现场日志中扩展缺表错误最后出现在第 25099 行，早于 09:59 及后续建单失败。
- 最早的现场锁冲突发生于独立升级工具提交 `6a540bfb`（08:57:38）之前。01:52 的日志记录的是客户端内置迁移。现有日志不能确定后来是否有其他进程打开同一文件。
- 合成实验 `fev-sqlite-write-contention-repro/2026-11-24T141850` 的结果为 `pass`，确认外部写事务足以复现建单失败。现场锁持有者仍缺少连接与事务时序证据，现场根因保持 `INCONCLUSIVE`。

- 同库双 Context 写锁的既有事故：[`2026-08-28-materialclient-product-ef-isolation/03-同库双Context设置保存锁.md`](../../2026-08-28-materialclient-product-ef-isolation/03-同库双Context设置保存锁.md)。
- 称重周期并发、失败反馈与异常恢复的调查：[`2026-11-18-weighing-kernel-reliability/00-调研总览.md`](../../2026-11-18-weighing-kernel-reliability/00-调研总览.md)。
