# fev-standard-weigh-waybill

## 目的 / Goal

`fev-standard-weigh-waybill`

Status: **active**

对已进入称重主窗的 `MaterialClient.exe`（Standard），用诊断口注入一张测试车牌、一次重车稳定重量和一次轻车稳定重量，观察是否产生 `WeighingMode = 0` 的 `Waybill`。默认收料：先重后轻，离磅后匹配。

探针与固废共用 `fev-solidwaste-weigh-lpr/scripts/probe-fev-solidwaste-weigh-lpr.ts`。

## 非目标

- 不修改 `repos/` 业务称重逻辑，不 `ProjectReference` 到 `repos/`
- 不改 `MaterialClient.db`、`appsettings`、`ScaleType` 或 `Client:DataDirectory`
- 不接收、不保存激活码或登录口令
- 不代替 OpenSpec；`FEASIBLE` / P2 不是产品已交付
- Agent 不宣布 P3

## 前置

1. 启动 Standard 诊断口（默认 `http://localhost:9933`）：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/MaterialClient/Start-MaterialClient.Standard.ps1 -EnableDiagnosticHost -StopRunning
```

2. 若出现授权窗口，由用户输入激活码。若出现登录窗，由用户登录。
3. 有人值守称重窗已打开，收发料类型为收料。
4. 地磅为测试模式（`ScaleType = TestMode`）。由用户准备库；本 Graph 不写 Settings。
5. 库与日志默认相对仓库根：
   - `repos/MaterialClient/.build-verify/MaterialClient/MaterialClient.db`
   - `repos/MaterialClient/.build-verify/MaterialClient/Logs`

固废用例在 `pipelines/graphs/materialclient/fev-solidwaste-weigh-lpr/`。两个宿主都听 `9933`，不能同时 cook。

## Sockets

| | |
|--|--|
| Start | `standard-diagnostic-host-idle` |
| End | `standard-waybill-observed` |
| Cook | `pnpm exec tsx`（`scripts/Invoke-FevStandardWeighWaybill.ps1`） |

## 规则

1. `POST /api/lpr/test-plate` 注入唯一车牌（`浙A` + 5 位）。出场前再注入同一张车牌。
2. `POST /api/scale/weight` 先离磅，再注入重车吨位并等待称重行，再离磅，再注入轻车吨位并等待称重行，最后离磅以触发匹配。
3. 证据：基线之后至少各 1 行重车、轻车，`WeighingMode = 0`，`PlateNumber` 等于注入值，两条记录的 `WaybillId` 已写入，且新 `Waybills` 行车牌与 `WeighingMode` 匹配。
4. 不写回 Settings。

## 判别

| cook `result` | 含义 |
|---------------|------|
| `pass` | 匹配的 Standard `Waybill` 出现 → `fevVerdict: FEASIBLE` |
| `fail` | 重车与轻车行都出现，但没有对应 `Waybill` → `fevVerdict: INFEASIBLE` |
| `blocked` | 诊断口不可达、非测试模式、称重未启动、只落下一条称重行 → `fevVerdict: INCONCLUSIVE` |

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
powershell -ExecutionPolicy Bypass -File pipelines/graphs/materialclient/fev-standard-weigh-waybill/scripts/Invoke-FevStandardWeighWaybill.ps1
```

默认假定进程已就绪。可选 `-StartHost`：只调用 `Start-MaterialClient.Standard.ps1 -EnableDiagnosticHost`。授权、登录、测试模式由用户处理。
