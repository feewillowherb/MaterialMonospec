# 01 FEV — 固废测试 API 称重与车牌

> 环：`Unknown → Experiment → Evidence → Verdict`  
> 只回答「固废宿主能否用测试 API 完成一次车牌注入加称重建单」。不是 Capability 交付。

## 1. 问题（Unknown）

`MaterialClient.SolidWaste.exe` 与 `MaterialClient.exe` 在诊断口已开启、用户已完成授权与登录、有人值守称重窗已打开、地磅为测试模式、收发料为收料时：

1. `POST /api/lpr/test-plate` 注入一张车牌；
2. `POST /api/scale/weight` 先注入重车吨位，离磅后再注入轻车吨位，再离磅；

能否新增一条 `Waybill`，且 `PlateNumber` 等于注入车牌、`WeighingMode` 等于该宿主（固废 `1`，Standard `0`），两条新称重行的 `WaybillId` 指向它？

## 2. 实验（Experiment）

| 项 | 内容 |
|----|------|
| 宿主 | `scripts/MaterialClient/Start-MaterialClient.SolidWaste.ps1 -EnableDiagnosticHost` |
| 诊断口 | `http://localhost:9933`（`GET /`、`POST /api/lpr/test-plate`、`POST /api/scale/weight`） |
| 库 / 日志 | `repos/MaterialClient/.build-verify/MaterialClient.SolidWaste/MaterialClient.db` 与同目录 `Logs`（按日期分子目录） |
| Graph | `pipelines/graphs/materialclient/fev-solidwaste-weigh-lpr/` |
| 判别 | cook `pass` → `FEASIBLE`；重车与轻车行都在但没有 `Waybill` → `INFEASIBLE`；口不可达、非测试模式、未进称重窗、只落下一条称重行 → `INCONCLUSIVE` |

Cook 不改库、不改 `appsettings`、不写激活码。`ScaleType = TestMode` 由用户事先准备。诊断口使用 `MinimalWebHost__Urls`（`9933`）。收料匹配在离磅时发生：重车行在前，轻车行在后，重量差须大于配置的 `MinWeightDiff`（默认 1 吨）。Standard 与固废不能同时占用 `9933`。

启动：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/MaterialClient/Start-MaterialClient.SolidWaste.ps1 -EnableDiagnosticHost -StopRunning
```

出现授权窗口时，由用户输入激活码。授权后若出现登录窗，由用户登录。进入称重主窗后再 cook：

```powershell
powershell -ExecutionPolicy Bypass -File pipelines/graphs/materialclient/fev-solidwaste-weigh-lpr/scripts/Invoke-FevSolidWasteWeighLpr.ps1
```

## 3. 证据（Evidence）

| 字段 | 值 |
|------|-----|
| graphId | `fev-solidwaste-weigh-lpr` |
| graphPath | `pipelines/graphs/materialclient/fev-solidwaste-weigh-lpr` |
| runId | `2026-11-19T142009` |
| result | `pass` |
| fevVerdict | `FEASIBLE` |
| P0–P2 | `pass` |
| P3 | `not-judged` |
| 不含密钥 | 是。激活码与登录口令不进入本夹、`config.yaml` 或 `runs/` |

观察：

- 宿主仍是 13:56 起的 `MaterialClient.SolidWaste`，诊断口 `http://localhost:9933`。
- 注入车牌 `浙A5V6PD`。重车 `12.5` 吨为 `WeighingRecords.Id=2`，轻车 `1.37` 吨为 `Id=3`，`WeighingMode=1`。
- 离磅后两条记录的 `WaybillId` 都是 `872054915989573`。`Waybills` 该行 `PlateNumber=浙A5V6PD`，`WeighingMode=1`。
- 13:56 的 `2026-11-19T135625` 只覆盖单条称重行，不再作为榜单证据。
- Standard Graph `fev-standard-weigh-waybill` 使用同一探针、`WeighingMode=0`。本次未 cook。

## 4. Verdict

| Verdict | 含义 |
|---------|------|
| `FEASIBLE` | 匹配的固废称重行出现，测试 API 路径可继续设计 |
| `INFEASIBLE` | 诊断口注入成功且称重管线已判稳，但没有 `WeighingMode = 1` 且车牌、吨位都匹配的新行 |
| `INCONCLUSIVE` | 证据不够：未启动、未授权、未登录、非测试模式、诊断口未监听 |

**当前 Verdict：固废 `FEASIBLE`（2026-11-19 14:20，runId `2026-11-19T142009`）。** Standard 尚未 cook。P3 未判定。

## 5. 人闸

- 授权窗口出现时，激活码只由用户在窗口输入。
- 登录窗口出现时，账号由用户输入。
- P3 由用户判定。Agent 不得把 cook 的 P2 写成产品通过。
