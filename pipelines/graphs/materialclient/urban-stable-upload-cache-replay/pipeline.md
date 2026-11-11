# urban-stable-upload-cache-replay

## 目的 / Goal

`urban-stable-upload-cache-replay`

Status: **active**（experimental，net10.0）

用脚本重放 [`docs/2026-11-11-urban-stable-upload-cache/02-车牌时序.md`](../../../../docs/2026-11-11-urban-stable-upload-cache/02-车牌时序.md) 里会分叉的车牌时序。不接场地，不读地磅日志，不写生产库。

## 非目标

- 不修改 `repos/` 业务代码，不 `ProjectReference` 到 `repos/`
- 不覆盖 `urban-busy-weighing-sim`。那条 Graph 仍对照 2026-11-10 的 `07`
- 不把 `02` 的每一行都做成一个场景
- 不模拟上传队列和道闸。已经发出去之后再改牌，这里判不了
- 不替代 OpenSpec。cook 的 P2 不是产品通过。Agent 不宣布 P3

## 配置指针

- `./config.yaml`
- `./fixtures/scenarios.json`
- `./secrets.example.yaml`（本 Graph 无密钥）

## Sockets

| | |
|--|--|
| Start | `scripted-weight-and-plate` |
| End | `bill-replay-compared` |
| Cook | `dotnet run`（`scripts/Invoke-UrbanStableUploadCacheReplay.ps1`） |

## 规则

稳定后建单并标 `Pending`。已产生缓存记下建单当时的车牌。`weight > MinWeightThreshold` 且 `recordId` 还在时，不再进入下一次稳定。进入 `OffScale` 的条件是 `weight < MinWeightThreshold`（默认 0.5 吨），同时清掉已产生缓存。满 900 秒仍未进入 `OffScale` 时，清掉已产生缓存和 `recordId`，并回到可再次稳定的状态，允许再产生一笔。

| 场景 | 对照 |
|------|------|
| `same-plate-held` | 同一张 A 在仍高于阈值时再出现，只有 1 笔 |
| `other-plate-held` | 建单后出现 B，`recordId` 还在，仍然 1 笔 A |
| `late-plate` | 稳定后才到 A，建单快照是空牌 |
| `late-plate-rewrite` | 进入 `OffScale` 时把这张单重写成 A |
| `offscale-same-plate` | `OffScale` 之后 A 再稳定，第 2 笔 |
| `threshold-flicker` | 阈值下抖一下再稳定，第 2 笔 |
| `fallback-same-plate` | 900 秒后同一张 A 再产生一笔 |
| `fallback-other-plate` | 900 秒前 B 已经次数更多，第 2 笔是 B |

## 证据包

相对本次 `runs/<yyyy-MM-ddTHHmmss>/`：

| collector | required | sink |
|-----------|----------|------|
| summary | yes | `summary.json` |
| report | yes | `report.md` |
| manifest | yes | `manifest.yaml` |

## Invoke

```powershell
powershell -ExecutionPolicy Bypass -File pipelines/graphs/materialclient/urban-stable-upload-cache-replay/scripts/Invoke-UrbanStableUploadCacheReplay.ps1
```

## 人闸 / Gate

- 最终验收：用户 `pass` / `fail`
- 上传队列和道闸未模拟

## 判定级别

| 级 | 谁判 |
|----|------|
| P0 运行时能启动 | cook |
| P1 八个场景已重放 | cook |
| P2 笔数、车牌与夹具一致 | cook |
| P3 业务上能否按这个缓存改产品 | **用户** |
