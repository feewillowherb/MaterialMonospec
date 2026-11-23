# fev-solidwaste-extreme-condition

## 目的 / Goal

`fev-solidwaste-extreme-condition`

Status: **active**

对已进入称重主窗的 `MaterialClient.SolidWaste.exe` 做极端工况：把重车、离磅、轻车、离磅四档测试重量连续写入诊断口，中间不等待。观察重量还堆在测试地磅队列里时，消化完成后是否仍按顺序落下两条称重行并配出一条 `WeighingMode = 1` 的 `Waybill`。

对应调研：[`docs/2026-11-19-solidwaste-extreme-condition-fev/01-FEV-极端工况.md`](../../../../docs/2026-11-19-solidwaste-extreme-condition-fev/01-FEV-极端工况.md)。

按节拍等待的配单用例在 `fev-solidwaste-weigh-lpr`。本 Graph 不替代它。

## 非目标

- 不修改 `repos/` 业务称重逻辑，不 `ProjectReference` 到 `repos/`
- 不改 `MaterialClient.db`、`appsettings`、`ScaleType` 或 `Client:DataDirectory`
- 不接收、不保存激活码或登录口令
- 不模拟相机超时、数据库锁或 CPU 停顿
- 不代替 OpenSpec；`FEASIBLE` / P2 不是产品已交付
- Agent 不宣布 P3

## 前置

1. 启动固废诊断口（默认 `http://localhost:9933`）：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/MaterialClient/Start-MaterialClient.SolidWaste.ps1 -EnableDiagnosticHost -StopRunning
```

2. 若出现授权窗口，由用户输入激活码。若出现登录窗，由用户登录。
3. 有人值守称重窗已打开，收发料类型为收料。
4. 地磅为测试模式（`ScaleType = TestMode`）。由用户准备库；本 Graph 不写 Settings。
5. 库与日志默认相对仓库根：
   - `repos/MaterialClient/.build-verify/MaterialClient.SolidWaste/MaterialClient.db`
   - `repos/MaterialClient/.build-verify/MaterialClient.SolidWaste/Logs`

与 `fev-solidwaste-weigh-lpr` 不能同时占用 `9933`。

## Sockets

| | |
|--|--|
| Start | `solidwaste-diagnostic-host-idle` |
| End | `solidwaste-extreme-condition-observed` |
| Cook | `pnpm exec tsx`（`scripts/Invoke-FevSolidWasteExtremeCondition.ps1`） |

## 规则

1. 先离磅并等待，使爆发从离磅状态开始。
2. `POST /api/lpr/test-plate` 注入唯一车牌（`浙A` + 5 位）。
3. 连续 `POST /api/scale/weight`：重车、离磅、轻车、离磅。四次返回之间不插入等待。
4. 四次都返回时，基线之后还没有新称重行，才算队列堆积已经发生。
5. 之后最多等待 `drainWaitMs`。通过条件：恰好两条新行，顺序为重车然后轻车，车牌与 `WeighingMode = 1` 匹配，两条 `WaybillId` 指向同一条新 `Waybill`。

## 判别

| cook `result` | 含义 |
|---------------|------|
| `pass` | 爆发时行尚未出现，消化后顺序与 Waybill 都正确 → `fevVerdict: FEASIBLE` |
| `fail` | 堆积已发生，但行数、顺序、车牌或 Waybill 不对 → `fevVerdict: INFEASIBLE` |
| `blocked` | 诊断口不可达、非测试模式、称重未启动，或爆发结束时行已经写完、堆积没有形成 → `fevVerdict: INCONCLUSIVE` |

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
powershell -ExecutionPolicy Bypass -File pipelines/graphs/materialclient/fev-solidwaste-extreme-condition/scripts/Invoke-FevSolidWasteExtremeCondition.ps1
```

默认假定进程已就绪。可选 `-StartHost`。授权、登录、测试模式由用户处理。
