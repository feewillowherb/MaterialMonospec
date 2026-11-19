# fev-solidwaste-weigh-lpr

## 目的 / Goal

`fev-solidwaste-weigh-lpr`

Status: **active**

对已进入称重主窗的 `MaterialClient.SolidWaste.exe`，用诊断口注入测试车牌和测试地磅重量，观察是否落下一条 `WeighingMode = 1`、车牌与吨位都匹配的 `WeighingRecords`。

对应调研：[`docs/2026-11-19-solidwaste-weigh-lpr-fev/01-FEV-测试API称重与车牌.md`](../../../../docs/2026-11-19-solidwaste-weigh-lpr-fev/01-FEV-测试API称重与车牌.md)。

## 非目标

- 不修改 `repos/` 业务称重逻辑，不 `ProjectReference` 到 `repos/`
- 不改 `MaterialClient.db`、`appsettings`、`ScaleType` 或 `Client:DataDirectory`
- 不接收、不保存激活码或登录口令
- 不代替 OpenSpec；`FEASIBLE` / P2 不是产品已交付
- Agent 不宣布 P3

## 前置

1. 启动固废诊断口（默认 `http://localhost:9933`）：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/MaterialClient/Start-MaterialClient.SolidWaste.ps1 -EnableDiagnosticHost -StopRunning
```

2. 若出现授权窗口，由用户输入激活码。若出现登录窗，由用户登录。
3. 有人值守称重窗已打开（`AttendedWeighingService` 已启动）。
4. 地磅为测试模式（`ScaleType = TestMode`）。由用户准备库；本 Graph 不写 Settings。
5. 库与日志默认相对仓库根：
   - `repos/MaterialClient/.build-verify/MaterialClient.SolidWaste/MaterialClient.db`
   - `repos/MaterialClient/.build-verify/MaterialClient.SolidWaste/Logs`

海康 LPR 配置会跳过 Web Host。诊断口不可达时 cook 为 `blocked`，Verdict 为 `INCONCLUSIVE`。

## Sockets

| | |
|--|--|
| Start | `solidwaste-diagnostic-host-idle` |
| End | `solidwaste-weigh-lpr-observed` |
| Cook | `pnpm exec tsx`（`scripts/Invoke-FevSolidWasteWeighLpr.ps1`） |

## 规则

1. `POST /api/lpr/test-plate` 注入唯一车牌（`浙A` + 5 位）。
2. `POST /api/scale/weight` 先注入离磅重量，再注入稳定吨位，并等待判稳。
3. 证据：基线 `Id` 之后至少 1 行，`WeighingMode = 1`，`PlateNumber` 等于注入值，`TotalWeight` 在夹具容差内。
4. 结束时再注入离磅重量。不写回 Settings。

## 判别

| cook `result` | 含义 |
|---------------|------|
| `pass` | 匹配固废行出现 → `fevVerdict: FEASIBLE` |
| `fail` | 注入成功且日志已判稳，但没有匹配行 → `fevVerdict: INFEASIBLE` |
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
powershell -ExecutionPolicy Bypass -File pipelines/graphs/materialclient/fev-solidwaste-weigh-lpr/scripts/Invoke-FevSolidWasteWeighLpr.ps1
```

默认假定进程已就绪。可选 `-StartHost`：只调用 `Start-MaterialClient.SolidWaste.ps1 -EnableDiagnosticHost`。授权、登录、测试模式由用户处理。

## 人闸 / Gate

- 授权窗口：用户输入激活码
- 登录窗口：用户登录
- 称重窗已打开
- 最终验收：用户 `pass` / `fail`
- Agent 不得把本 Graph 的 P2 写成产品通过

## 判定级别

| 级 | 谁判 |
|----|------|
| P0 诊断口 `GET /` 可达 | cook |
| P1 车牌与重量注入已成功 | cook |
| P2 一条 `WeighingMode = 1` 且车牌、吨位匹配的新行 | cook |
| P3 是否据此继续固废称重设计 | **用户** |
