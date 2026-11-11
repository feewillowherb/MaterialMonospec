# urban-stable-upload-cache-probe

## 目的 / Goal

`urban-stable-upload-cache-probe`

Status: **active**

对已经启动的 `MaterialClient.Urban` 做运行时探测。操作只走诊断 HTTP API。判定读本地 SQLite 新行和本次新增日志。不读窗口像素，也不把界面控件当证据。

与 `urban-stable-upload-cache-replay` 不是同一个 goal。那条 Graph 仍是不注入产品代码的纯函数重放。

## 非目标

- 不修改 `repos/` 业务代码，不 `ProjectReference` 到 `repos/`
- 不删除本地称重行
- 不覆盖已有 `runs/`
- 默认 cook 不等待 910 秒。`-IncludeFallback` 才跑兜底场景
- 不把 cook 的 P2 写成产品通过。Agent 不宣布 P3

## 前置

1. 用诊断口启动 Urban，地磅工作目录保持在 `.build-verify/Urban`：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/MaterialClient/Start-MaterialClient.Urban.ps1 -EnableDiagnosticHost
```

2. 诊断口默认 `http://localhost:9933`。本机路径若不同，写 `secrets.local.yaml` 的 `baseUrl`、`databaseRel`、`logRel`。

## Sockets

| | |
|--|--|
| Start | `diagnostic-host-idle` |
| End | `stable-upload-observed` |
| Cook | `pnpm exec tsx` |

## 规则

`POST /api/scale/weight` 要求地磅已是测试模式。Cook 会把读到的整份设置改成 `scaleType = 2`，并按场景切换 `enableUploadOnStable`，结束时把原设置 POST 回去。

重量注入由产品里的测试预处理器爬升并保持约 3 秒。每个重量动作之后等待夹具里的 `settleMs`（默认 8 秒）。每个场景先注入一次低于阈值的重量，让仍在磅上的周期走 OffScale 并清空车牌缓存，再记录当时的最大 `WeighingRecords.Id`。

`sync: Pending` 表示该行已经离开 `WeighingInProgress`。若上传线程已经把它写成 `Synced` 或 `Failed`，这一格仍算通过。`sync: WeighingInProgress` 必须仍是 3。

| 场景 | 对照 |
|------|------|
| `flag-off-promotes-on-offscale` | 开关关闭时稳定后仍是 `WeighingInProgress`，低于阈值后才是 `Pending` |
| `flag-on-same-plate-held` | 开关打开，稳定后即 `Pending`；同一车牌再注入仍是 1 笔 |
| `flag-on-other-plate-held` | 记录还在时换一张牌，仍是 1 笔，车牌保持第一张 |
| `offscale-same-plate` | 低于阈值之后同一车牌可以再产生 1 笔 |
| `threshold-equal-keeps-one` | 重量等于阈值后再回升，仍是 1 笔 |
| `threshold-flicker-second-bill` | 重量低于阈值后再稳定，变成 2 笔 |
| `fallback-same-plate` | 仅 `-IncludeFallback`。稳定后等待 910 秒，期望出现第 2 笔 |

车牌在每次场景前加时间戳前缀，只统计该场景开始时 `WeighingRecords.Id` 之后的新行。

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
powershell -ExecutionPolicy Bypass -File pipelines/graphs/materialclient/urban-stable-upload-cache-probe/scripts/Invoke-UrbanStableUploadCacheProbe.ps1
```

包含 910 秒兜底：

```powershell
powershell -ExecutionPolicy Bypass -File pipelines/graphs/materialclient/urban-stable-upload-cache-probe/scripts/Invoke-UrbanStableUploadCacheProbe.ps1 -IncludeFallback
```

## 人闸 / Gate

- 最终验收：用户 `pass` / `fail`
- 诊断口没起来时 cook 记 `blocked`，不是业务失败
- 新称重行会留在本地 Urban 库里

## 判定级别

| 级 | 谁判 |
|----|------|
| P0 诊断口 `GET /` 返回 200 | cook |
| P1 至少一次测试 API 写入已返回 200 | cook |
| P2 默认场景的笔数、车牌、`SyncStatus` 与夹具一致 | cook |
| P3 业务上是否接受这次运行时结果 | **用户** |
