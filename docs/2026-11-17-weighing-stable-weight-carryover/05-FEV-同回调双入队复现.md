# 05 FEV — 同回调双入队复现

> 对应 OpenSpec：`openspec/changes/fix-weighing-stable-single-enqueue`  
> 环：`Unknown → Experiment → Evidence → Verdict`  
> 本 FEV **只**回答「缺陷能否在真实进程上受控复现」；**不是** Capability 交付，**不**授权改产品行为（改代码仍走该 change 的 apply）。  
> 手段：**集成**（诊断 API + 活进程），不是单元测试。

## 1. 问题（Unknown）

**能否**在已启动的 `MaterialClient.exe` 上，用诊断口注入车牌与测试地磅重量，稳定复现：

> 同一次 `OnWeightAndStatusChanged`（`WaitingForStability → WeightStabilized`）因 status-transition 与 backup **各入队一次** `OnWeightStabilizedAsync`，日志同时出现两行，并对仓库产生 **≥ 2** 条同吨 `WeighingRecords`？

若能复现，则 `fix-weighing-stable-single-enqueue` 所针对的双任务源成立，可继续按 design 做「本回调已入队」标志。  
若不能复现，则不得把「同帧双入队」写成当前主干上的已证实缺陷。

## 2. 实验（Experiment）

| 项 | 内容 |
|----|------|
| 环境 | `scripts/MaterialClient/Start-MaterialClient.ps1 -EnableDiagnosticHost` 启的真实进程；已登录；有人值守称重窗已开；`ScaleType=TestMode(2)` |
| Graph | `pipelines/graphs/materialclient/fev-stable-dual-enqueue-repro/` |
| API | `POST /api/lpr/test-plate`、`POST /api/scale/weight`（默认 `http://localhost:9933`） |
| 观测 | 日志：`Weight stabilized (status transition)` + `Weight stabilized (backup check)`；SQLite：基线后 ≥2 同吨行 |
| 判别 | cook `result=pass` → 复现成立；`fail` → 不支持「同帧双入队」；`blocked` → 环境未就绪 |

启动：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/MaterialClient/Start-MaterialClient.ps1 -EnableDiagnosticHost -StopRunning
```

Cook：

```powershell
powershell -ExecutionPolicy Bypass -File pipelines/graphs/materialclient/fev-stable-dual-enqueue-repro/scripts/Invoke-FevStableDualEnqueueRepro.ps1
```

说明：主端 `MinimalWebHost` **无** `/api/settings`；测试地磅与 `MaterialClient.db` **由用户自行准备**。Cook / `-StartHost` **不**改库、不改 `appsettings`。

单元测试 `WeighingStableWeightCarryoverReproductionTests` 仍可作旁路对照，**不**计入本 FEV 的 Verdict 证据包。

## 3. 证据（Evidence）

| 字段 | 值 |
|------|-----|
| 运行身份 | 见 Graph `runs/<runId>/` 的 `summary.json`（`graphId=fev-stable-dual-enqueue-repro`） |
| 命令 | 上表 Start + Invoke |
| 工作目录 | 仓库根；库/日志在 `repos/MaterialClient/.build-verify/MaterialClient/` |
| 观察 | 以该次 `summary.json` 的 `fevVerdict` / `observations` / `log-excerpt.txt` / 新行账单为准 |
| 产品代码基线 | 当时 `AttendedWeighingService.OnWeightAndStatusChanged` **尚未**加「本回调已入队」标志 |
| 不含密钥 | 是 |

（首次 cook 完成后把本表 `runId` / `fevVerdict` 填实。）

## 4. Verdict

| Verdict | 含义（本问题） |
|---------|----------------|
| `FEASIBLE` | 集成路径上受控复现成功；双入队缺陷可作 fix change 的实证前提 |
| `INFEASIBLE` | 诊断口与称重已就绪，但得不到双日志/双行；勿按「同帧双入队」路线硬修 |
| `INCONCLUSIVE` | 证据不足（诊断口不可达、非测试模式、称重未开等） |

**当前 Verdict：`INCONCLUSIVE`（待 Graph cook）**

此 Verdict **不是**产品已修好。`FEASIBLE` ≠ OpenSpec 已实现 ≠ ICD PASS。

## 5. 边界

- `FEASIBLE` ≠ OpenSpec 已实现 ≠ ICD PASS。
- 现场日志（`01`）是另一路证据；本 FEV 只覆盖**诊断口集成复现**。
- 音响旁路已另案处理；本实验不依赖音响离线。
