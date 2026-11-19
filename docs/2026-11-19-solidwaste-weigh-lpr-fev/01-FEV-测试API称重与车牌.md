# 01 FEV — 固废测试 API 称重与车牌

> 环：`Unknown → Experiment → Evidence → Verdict`  
> 只回答「固废宿主能否用测试 API 完成一次车牌注入加称重建单」。不是 Capability 交付。

## 1. 问题（Unknown）

`MaterialClient.SolidWaste.exe` 在诊断口已开启、用户已完成授权与登录、有人值守称重窗已打开、地磅为测试模式时：

1. `POST /api/lpr/test-plate` 注入一张车牌；
2. `POST /api/scale/weight` 注入一次稳定吨位；

能否在 `WeighingRecords` 新增至少一行，且该行 `WeighingMode = 1`、`PlateNumber` 等于注入车牌、`TotalWeight` 等于注入吨位？

## 2. 实验（Experiment）

| 项 | 内容 |
|----|------|
| 宿主 | `scripts/MaterialClient/Start-MaterialClient.SolidWaste.ps1 -EnableDiagnosticHost` |
| 诊断口 | `http://localhost:9933`（`GET /`、`POST /api/lpr/test-plate`、`POST /api/scale/weight`） |
| 库 / 日志 | `repos/MaterialClient/.build-verify/MaterialClient.SolidWaste/MaterialClient.db` 与同目录 `Logs`（按日期分子目录） |
| Graph | `pipelines/graphs/materialclient/fev-solidwaste-weigh-lpr/` |
| 判别 | cook `pass` → `FEASIBLE`；诊断口与称重已就绪但没有匹配固废行 → `INFEASIBLE`；口不可达、非测试模式、未进称重窗 → `INCONCLUSIVE` |

Cook 不改库、不改 `appsettings`、不写激活码。`ScaleType = TestMode` 由用户事先准备。海康 LPR 会让 `MinimalWebHostService` 直接返回、诊断口不监听；这种情况记为 `INCONCLUSIVE`。

启动：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/MaterialClient/Start-MaterialClient.SolidWaste.ps1 -EnableDiagnosticHost -StopRunning
```

出现授权窗口时，由用户输入激活码。授权后若出现登录窗，由用户登录。进入称重主窗后再 cook：

```powershell
powershell -ExecutionPolicy Bypass -File pipelines/graphs/materialclient/fev-solidwaste-weigh-lpr/scripts/Invoke-FevSolidWasteWeighLpr.ps1
```

## 3. 证据（Evidence）

尚未 cook。首次运行后以该次 `runs/<runId>/summary.json` 为准，身份字段为 `graphId`、`graphPath`、`runId`、`result`。

| 字段 | 值 |
|------|-----|
| graphId | `fev-solidwaste-weigh-lpr` |
| graphPath | `pipelines/graphs/materialclient/fev-solidwaste-weigh-lpr` |
| runId | 待 cook |
| result | 待 cook |
| 不含密钥 | 是。激活码与登录口令不进入本夹、`config.yaml` 或 `runs/` |

## 4. Verdict

| Verdict | 含义 |
|---------|------|
| `FEASIBLE` | 匹配的固废称重行出现，测试 API 路径可继续设计 |
| `INFEASIBLE` | 诊断口注入成功且称重管线已判稳，但没有 `WeighingMode = 1` 且车牌、吨位都匹配的新行 |
| `INCONCLUSIVE` | 证据不够：未启动、未授权、未登录、非测试模式、诊断口未监听 |

**当前 Verdict：`INCONCLUSIVE`（待 Graph cook）**

## 5. 人闸

- 授权窗口出现时，激活码只由用户在窗口输入。
- 登录窗口出现时，账号由用户输入。
- P3 由用户判定。Agent 不得把 cook 的 P2 写成产品通过。
