# fev-stable-dual-enqueue-repro

## 目的 / Goal

`fev-stable-dual-enqueue-repro`

Status: **active**

**修复前 FEV（集成）**：对已启动的 `MaterialClient.exe` 诊断口注入车牌与测试地磅重量，观察同一次判稳是否同时打出 `status transition` 与 `backup check`，并在 SQLite 落出 **≥ 2** 条同吨 `WeighingRecords`。

对应调研：[`docs/2026-11-17-weighing-stable-weight-carryover/05-FEV-同回调双入队复现.md`](../../../../docs/2026-11-17-weighing-stable-weight-carryover/05-FEV-同回调双入队复现.md)。  
对应 OpenSpec（尚未 apply）：`openspec/changes/fix-weighing-stable-single-enqueue`。

## 非目标

- 不修改 `repos/` 业务称重逻辑，不 `ProjectReference` 到 `repos/`
- 不用 xUnit / 反射当本 Graph 的 cook 证据（单元复现可另存，不替代本 FEV）
- 不代替 OpenSpec apply；`FEASIBLE` / P2 **不是**产品已修好
- Agent 不宣布 P3

## 前置

1. 启动诊断口（本机默认 `http://localhost:9933`）：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/MaterialClient/Start-MaterialClient.ps1 -EnableDiagnosticHost -StopRunning
```

2. 登录并打开**有人值守称重**界面（`AttendedWeighingService.StartAsync` 须已跑）。
3. 地磅须为测试模式（`ScaleType = 2`）。**由用户自行准备 `MaterialClient.db` / UI 设置**；本 Graph **不**改库、不改 `appsettings`、不拷贝 DataDirectory。
4. 库与日志默认相对仓库根：
   - `repos/MaterialClient/.build-verify/MaterialClient/MaterialClient.db`
   - `repos/MaterialClient/.build-verify/MaterialClient/Logs`

## Sockets

| | |
|--|--|
| Start | `diagnostic-host-idle` |
| End | `dual-enqueue-reproduced` |
| Cook | `pnpm exec tsx`（`scripts/Invoke-FevStableDualEnqueueRepro.ps1`） |

## 规则

1. `POST /api/lpr/test-plate` 注入唯一车牌前缀。
2. `POST /api/scale/weight` 先低于阈值（离磅），再注入稳定吨位并等待判稳窗口。
3. 证据同时看：
   - 日志：同一窗口内出现 `Weight stabilized (status transition)` **与** `Weight stabilized (backup check)`
   - SQLite：基线 `Id` 之后 ≥ 2 条新行，且 `TotalWeight` 同吨（容差见夹具）
4. 结束时再注入离磅重量。不写回、不改 Settings。

## 判别

| cook `result` | 含义 |
|---------------|------|
| `pass` | 双入队日志 + 同吨双行均成立 → `fevVerdict: FEASIBLE` |
| `fail` | 诊断口可达且已操作，但未观察到双入队/双行 → `fevVerdict: INFEASIBLE` |
| `blocked` | 诊断口不可达、非测试模式、称重未启动等 → `fevVerdict: INCONCLUSIVE` |

## 证据包

相对本次 `runs/<yyyy-MM-ddTHHmmss>/`：

| collector | required | sink |
|-----------|----------|------|
| summary | yes | `summary.json` |
| report | yes | `report.md` |
| manifest | yes | `manifest.yaml` |
| http | yes | `http.json` |
| log excerpt | yes | `log-excerpt.txt` |

## Invoke

```powershell
powershell -ExecutionPolicy Bypass -File pipelines/graphs/materialclient/fev-stable-dual-enqueue-repro/scripts/Invoke-FevStableDualEnqueueRepro.ps1
```

默认假定进程已就绪。可选 `-StartHost`：只调用 `Start-MaterialClient.ps1 -EnableDiagnosticHost`（不改库/配置）。登录、称重窗、TestMode 由用户处理。

## 人闸 / Gate

- 进程已登录且称重窗打开
- 最终验收：用户 `pass` / `fail`
- Agent 不得把本 Graph 的 P2 写成产品通过

## 判定级别

| 级 | 谁判 |
|----|------|
| P0 诊断口 `GET /` 可达 | cook |
| P1 车牌与重量注入已成功 | cook |
| P2 双入队日志 + 同吨 ≥2 行 | cook |
| P3 是否据此推进 single-enqueue apply | **用户** |

## 退役提示

`fix-weighing-stable-single-enqueue` apply 后：退役本 Graph，或另开回归 Graph（期望单次判稳仅 1 行）。
