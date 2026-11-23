# fev-recycle-weigh-cycle

## 目的 / Goal

`fev-recycle-weigh-cycle`

Status: **active**

对已打开称重窗的 `MaterialClient.Recycle.exe`，在主动抓拍保持开启时，用诊断口只注入车牌、再完成上磅和下磅，观察是否保存 `WeighingMode = 301` 的称重记录、LPR 照片，并在没有审批时进入待上报。

## 非目标

- 不修改 `repos/` 业务称重逻辑，不 `ProjectReference` 到 `repos/`
- 不改 `MaterialClient.db`、`appsettings`、`ScaleType` 或 `EnableTriggerLprCapture`
- 测试车牌请求不带图片
- 不接收、不保存激活码
- 不在 cook 结束时关闭客户端
- 不代替 OpenSpec；`FEASIBLE` / P2 不是产品已交付
- Agent 不宣布 P3

## 前置

1. 地磅为测试模式（`ScaleType = TestMode`）。主动抓拍 `EnableTriggerLprCapture` 为 true。本 Graph 不写这两项。
2. 启动再生客户端。诊断口来自程序自己的 `MinimalWebHost`（默认 `http://localhost:9933`）。

```powershell
powershell -ExecutionPolicy Bypass -File scripts/MaterialClient/Start-MaterialClient.Recycle.ps1 -StopRunning
```

`-StopRunning` 只为换入新编译结果。进程起来之后，本 Graph 不再结束它。

3. 若出现授权窗口，由用户输入激活码。有人值守称重窗已打开。
4. 库与日志默认相对仓库根：
   - `repos/MaterialClient/.build-verify/MaterialClient.Recycle/MaterialClient.db`
   - `repos/MaterialClient/.build-verify/MaterialClient.Recycle/Logs`

固废图也听 `9933`。两个宿主不能同时 cook。

## Sockets

| | |
|--|--|
| Start | `recycle-diagnostic-host-idle` |
| End | `recycle-weigh-cycle-observed` |
| Cook | `pnpm exec tsx`（`scripts/Invoke-FevRecycleWeighCycle.ps1`） |

## 规则

1. 每辆车先多次 `POST /api/lpr/test-plate`，请求体只有车牌，没有图片字段。
2. `POST /api/scale/weight` 把重量抬到目标吨位并保持，直到称重行和 `AttachType = 5` 的 LPR 文件出现。
3. 然后明确下磅：`POST /api/scale/weight` 写 0，低于 0.5 吨，并等到日志出现正常下磅。
4. 证据：`WeighingMode = 301`，车牌等于注入值，LPR 文件存在，`WaybillId` 为空，`RecycleSyncStatus` 为 `Pending` 或 `Synced`。旧的 `RecycleWebReceiveState` 值 `Accepted` 仍按 `Synced` 计。
5. 两辆车按场景顺序各走一轮：`浙A35586D` 10 吨，`浙A33606D` 20 吨。

## 判别

| cook `result` | 含义 |
|---------------|------|
| `pass` | 两轮都有 LPR 照片、正常下磅、且无需审批就进入 `RecycleSyncStatus` 的 `Pending` 或 `Synced` → `fevVerdict: FEASIBLE` |
| `fail` | 称重行已出现，但没有 LPR、没有正常下磅，或下磅后仍未待上报 → `fevVerdict: INFEASIBLE` |
| `blocked` | 诊断口不可达、非测试模式、主动抓拍关闭、称重未启动 → `fevVerdict: INCONCLUSIVE` |

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
powershell -ExecutionPolicy Bypass -File pipelines/graphs/materialclient/fev-recycle-weigh-cycle/scripts/Invoke-FevRecycleWeighCycle.ps1
```

默认会编译并启动再生客户端，结束时不关闭它。已在跑且不需要重新编译时用 `-NoStart`。

## 人闸 / Gate

- 授权窗口：用户输入激活码
- 称重窗已打开
- 最终验收：用户 `pass` / `fail`
- Agent 不得把本 Graph 的 P2 写成产品通过

## 判定级别

| 级 | 谁判 |
|----|------|
| P0 诊断口可达，且主动抓拍仍开启 | cook |
| P1 车牌与上磅、下磅注入已成功 | cook |
| P2 两条 `WeighingMode = 301` 的新行带 LPR 照片并进入待上报 | cook |
| P3 是否据此继续再生称重设计 | **用户** |
