# 00 · FEV：MaterialClient.Urban 启动客户端 API 100 周期称重 SQLite Busy 与 Recovery 阻塞验证

- **日期**：2026-11-25
- **范围**：真实启动 `MaterialClient.Urban.exe`（`Debug`，`repos/MaterialClient` HEAD `0f40d07`），通过诊断 API（`http://localhost:9933`）连续驱动 100 次上磅→判稳→离磅周期
- **生命周期**：`ACTIVE`
- **FEV Verdict**：`INFEASIBLE`（当前 Urban 实现在连续 100 次称重中**会出现 `SQLite Error 5: database is locked` 并永久丢失 3 条称重记录**）
- **关联 Graph**：[`pipelines/graphs/materialclient/fev-urban-weighing-cycles/pipeline.md`](../../pipelines/graphs/materialclient/fev-urban-weighing-cycles/pipeline.md)

## 可行性问题

真实启动 `MaterialClient.Urban` 客户端（启用 `UrbanMode`、`WeighingCycleRecoveryWorker` 及 `PollingBackgroundService`），通过本地诊断 API 连续完成 100 条称重数据：
1. 是否会出现 `SQLite Error 5: 'database is locked'`（`sqlite_busy`）或称重丢单？
2. `WeighingCycleRecoveryWorker`（`SupportsPersistentCycleRecovery => true`）是否是引起 block / `sqlite_busy` 的主因？若不是，实际持锁竞争源是谁？

本 FEV 只做实证观测，不修改产品代码、不创建 OpenSpec change。

## Unknown

1. Urban 客户端在 `SupportsPersistentCycleRecovery => true` 下，连续 100 周期 API 称重（无额外离磅等待）是否会触发 `sqlite_busy`。
2. 触发 `sqlite_busy` 的直接持锁方是 `WeighingCycleRecoveryWorker` / `PersistRecoveryStateAsync`，还是 `PollingBackgroundService` 或其他写路径。
3. 出现 `sqlite_busy` 时，建单耗时特征与 Recovery 状态变化。

## Experiment

### 输入与环境

- **源码基线**：`repos/MaterialClient` HEAD `0f40d07`（已包含 `abde6ae fix(solidwaste): squash fix-materialclient-sqlite-write-contention into main`）。
- **构建产物**：`repos/MaterialClient/.build-verify/Urban/MaterialClient.Urban.exe`（`Debug`）。
- **隔离运行配置**：
  - 全新独立 SQLite 工作库（未复用生产/旧库）与独立日志目录。
  - `MinimalWebHost__EnableOnStartup=true`，`MinimalWebHost__Urls=http://localhost:9933`。
  - 启动后通过 `POST /api/settings` 切换 `scaleSettings.scaleType = 2`（`ScaleType.TestMode`），保持默认 `defaultWeighingMode = 201`（`UrbanMode`）、`stabilityWindowMs = 3000`、`stabilityCheckIntervalMs = 200`、`UploadPollingPeriodMs = 80000`、`UploadBatchSize = 50`、`BackgroundServices:Polling = true`。
  - 服务端 `http://localhost:5000` 未启动（模拟现场网络不可达/上传超时重试场景）。

### 操作步骤

1. 启动 `MaterialClient.Urban.exe`，确认日志输出 `Urban PollingBackgroundService registered` 与 `Started monitoring truck scale weight changes`（即 `_recoveryWorker?.Start()` 已启动）。
2. 通过 API 探针连续执行 100 个称重周期（离磅后立即进入下一周期，无额外等待）：
   - `POST /api/lpr/test-plate` 注入唯一车牌
   - `POST /api/scale/weight` 注入稳定重量（10.95t–11.85t 循环）
   - 轮询只读 SQLite 确认 `WeighingRecords` 落库（超时 25s）
   - `POST /api/scale/weight` 注入离磅重量 `0.3t`，等待日志出现离磅完成
3. 100 周期结束后额外等待 10s，观察 `WeighingCycleRecoveryWorker` 是否有延迟重试或报错，随后对 SQLite 全表与运行日志做全量审计。

## Evidence

### 1. 100 周期总体实测数据

| 指标 | 实测结果 |
|---|---|
| 执行周期数 | **100 / 100**（总耗时 **855.8 秒**） |
| `WeighingRecords` 实际落库行数 | **97 / 100**（**永久丢失 3 条**） |
| 不同 `WeighingCycleId` 数 | **97** |
| `UrbanWeighingExtensions` 行数 | **97**（全部 `SyncStatus = 0 / Pending`） |
| `WeighingCycleRecovery` 状态分布 | 97 条全部为 `Completed(attempts=0, ended=false)` |
| `SQLite Error 5: 'database is locked'` 日志行数 | **9 行**（对应 **3 次建单失败**，每次 3 层异常日志） |
| `WeighingCycleRecoveryWorker` / `PersistRecoveryStateAsync` 报错数 | **0** |

> 注：Cycle 2（`浙A4QFD2`）在 Cycle 1 离磅完成前 65ms 注入车牌，实际生成了 `ID=2, PlateNumber=None` 的记录（未丢单、无锁错）；真正丢单的是 **Cycle 72、Cycle 75、Cycle 86**。

### 2. 三次 `SQLite Error 5` 精确时间线与堆栈

三次建单失败全部落在 **`MaterialClient.Common/Services/AttendedWeighing/WeighingRecordService.cs:line 200`**（`CreateForCycleAsync` → `_weighingRecordRepository.InsertAsync(weighingRecord, autoSave: true)` → `MaterialClientDbContext.SaveChangesAsync`）：

| 周期 | 车牌 | CycleId | 开始建单时刻 | `SQLite Error 5` 时刻 | 失败耗时 | 当时并发运行中的操作 |
|---|---|---|---|---|---:|---|
| Cycle 72 | `浙AHWDXC` | `881e42a1-56df-4d0e-a461-52951c3c9504` | `00:31:12.461` | `00:31:12.493` | **32 ms** | `PollingBackgroundService` 第 4 轮上传（`00:30:51`–`00:34:28`，正执行第 5 条 HTTP `POST /receive`） |
| Cycle 75 | `浙AT533A` | `d88afd45-c0f6-4067-aee1-2885a7c0b8ce` | `00:31:54.455` | `00:31:54.477` | **22 ms** | `PollingBackgroundService` 第 4 轮上传（正执行第 15 条 HTTP `POST /receive`） |
| Cycle 86 | `浙A1RUCH` | `4db22d5b-9eae-47d7-9ae7-f9dca535b933` | `00:33:38.262` | `00:33:38.294` | **32 ms** | `PollingBackgroundService` 第 4 轮上传（正执行第 39 条 HTTP `POST /receive`） |

### 3. 根因拆解（已证实 vs 待 A/B 对照）

1. **已排除：`WeighingCycleRecoveryWorker` 的 Recovery 写重试不是本次 3 次 `SQLite Error 5` 的原因**：
   - 本次 100 周期中，`WeighingCycleRecoveryWorker` 全程每秒执行 `GetListAsync()` 读扫描，但 **0 次进入写重试、0 条 Recovery 日志/报错**；全部 97 条落库记录在离磅时均一次完成 `FinalizeSealedRecordAsync` 并标记 `Completed(attempts=0)`。
   - 但由于 `CreateForCycleAsync` 在 `InsertAsync` 阶段即因锁失败，记录从未落库，**Recovery 机制也无法补救这 3 条丢单**。
2. **已观测到的事实与源码核对**：
   - 工作库实际处于默认 **`PRAGMA journal_mode = delete`**（非 WAL）。
   - 全部 3 次 `SQLite Error 5` 均落在 `PollingBackgroundService` 第 4 轮（`00:30:51`–`00:34:28`，50 条待传）期间，且均在 `WeighingRecordService.cs:200`（`MaterialClientDbContext.SaveChangesAsync`）**22–32ms 内**瞬时报错（未等 30s `Default Timeout`）。
   - 进一步核对源码发现：`PollingBackgroundService.cs:130` 的 `WithUow` 实际为 **`isTransactional: false`**，且 `UrbanServerUploadService.SubmitRecordAsync` 在 HTTP 失败时并不立即写库（仅在内存中改 `extension.SubmitMachineCode`，到整批结束 `uow.CompleteAsync()` 时才一次性落库，实测 DB 中共 50 条写入了 `SubmitMachineCode`）。
   - `CreateForCycleAsync` 开启默认 `DEFERRED` 事务后，`MaterialClientDbContext.ApplyAuditConcepts()` 先查 `UserSessions`（获取 `SHARED` 锁），再执行 `INSERT INTO WeighingRecords`（尝试 `SHARED → RESERVED` 锁升级）；若此时存在并发锁冲突，SQLite 会跳过 `busy_timeout` 立即返回 `SQLITE_BUSY`。
3. **尚未通过 A/B 对照彻底定责的部分**：
   - 当前日志未打印持锁连接/线程，因此虽然**明确排除了 Recovery 写重试**，但**尚不能 100% 排除 `WeighingCycleRecoveryWorker` 的每秒 `GetListAsync()` 全表读扫描**与其他并发读写（`PollingBackgroundService`、UI 刷新等）在 `journal_mode=delete` 下叠加触发锁冲突。
   - 最小对照实验：使用 `fev-urban-weighing-cycles` 在 **`BackgroundServices__Polling=false`** 下重跑 100 周期（仅保留 `WeighingCycleRecoveryWorker`），即可给出 100% 确定的归因。

### 4. 修复后 A/B 对照验证（OpenSpec `fix-sqlite-wal-on-migration` + Graph Run `2026-11-25T085427`）

在 `repos/MaterialClient` 分支 `fix-sqlite-wal-on-migration` 上修复 `SqliteMigrationHistoryMigrator` 提前创建空库的问题并在 `KernelDatabaseMigrator` 中显式确保 `PRAGMA journal_mode = WAL;` 后，重新构建 `MaterialClient.Urban.exe`，使用完全相同的环境（全新隔离库、Polling 开启、Recovery 开启、100 周期 `-Fast`）执行 `fev-urban-weighing-cycles`：

| 指标 | 修复前（`DELETE` 模式） | 修复后（`WAL` 模式，Run `2026-11-25T085427`） |
|---|---|---|
| `PRAGMA journal_mode` | `delete`（无伴生文件） | **`wal`**（已生成 `MaterialClient.db-wal` / `-shm`） |
| `WeighingRecords` 落库数 | 97 / 100（丢 3 单） | **100 / 100（0 丢单）** |
| `UrbanWeighingExtensions` 落库数 | 97 / 100 | **100 / 100** |
| `WeighingCycleRecovery` 状态 | 97 条 `Completed(attempts=0)` | **100 条 `Completed(attempts=0)`** |
| `SQLite Error 5` 次数 | **9 行（3 次建单失败）** | **0 行（0 次建单失败）** |

> 说明：Run `2026-11-25T085427` 的 `report.md` 标为 `fail` 仅因 `-Fast`（`departureSettleMs=0`）下 Cycle 2 车牌注入早于 Cycle 1 离磅收尾导致第 2 条记录 `PlateNumber=None`，但数据库仍完整落库 100/100 条记录与扩展，且全程 **0 次 SQLite 锁错误、0 次建单失败**。证据目录：[`pipelines/graphs/materialclient/fev-urban-weighing-cycles/runs/2026-11-25T085427/`](../../pipelines/graphs/materialclient/fev-urban-weighing-cycles/runs/2026-11-25T085427/report.md)。

## Verdict — `FEASIBLE`（WAL 恢复修复已实证消除本次 100 周期 `SQLite Error 5`）

- **当前实现可行性**：`INFEASIBLE`（在当前 Urban 实现下，100 条连续称重**会出现 `SQLite Error 5: database is locked` 并丢单 97/100**）。
- **核心发现**：
  1. **会复现 `sqlite_busy`**：100 周期中稳定复现 3 次 `SQLite Error 5`，导致 3 条称重记录永久丢失。
  2. **不是 Recovery 写重试带来的**：`WeighingCycleRecoveryWorker` 在 100 周期内 0 次写重试、0 次报错；但是否由其每秒 `GetListAsync()` 读扫描与 `PollingBackgroundService` / 其他并发连接在 `journal_mode=delete` 下共同触发，需要做一次关掉 Polling 的 A/B 对照才能 100% 确认。
  3. **修复路线方向**（需走 OpenSpec change 与人工确认）：
     - 将 `Urban/Backgrounds/PollingBackgroundService` 与 `UrbanServerUploadService` 中的网络请求移出 UoW（严格遵守 `traits/materialclient-sqlite-write-serialization-trait.md`：「网络、硬件和文件操作安排在写事务外」），按单条短事务提交状态更新。
     - 为 Urban 接入进程内按 SQLite 文件路径的业务写入串行化（覆盖 `WeighingRecordService`、`UrbanWeighingExtensionService`、`WeighingCycleRecoveryWorker`、`PollingBackgroundService`）。
     - 避免在写事务开启后由 `ApplyAuditConcepts()` 在 `INSERT` 前执行 `UserSessions` 查询升级锁（或在开启写事务前获取会话/使用 `BEGIN IMMEDIATE`）。
