# urban-busy-weighing-sim

## 目的 / Goal

`urban-busy-weighing-sim`

Status: **active**（experimental，net10.0）

用脚本重放称重规则，对照 [`docs/2026-11-10-urban-busy-weighing-upload-on-stable/07-直接上现场的后果.md`](../../../../docs/2026-11-10-urban-busy-weighing-upload-on-stable/07-直接上现场的后果.md)。不接场地，不读地磅日志，不写生产库。

## 非目标

- 不修改 `repos/` 业务代码，不 `ProjectReference` 到 `repos/`
- 不模拟道闸
- 不把叠车吨数拟合为现场合重。70 吨和 55 吨是脚本输入
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
| Cook | `dotnet run`（`scripts/Invoke-UrbanBusyWeighingSim.ps1`） |

## 三种规则

| 模式 | 行为 |
|------|------|
| `legacy` | 第一次判稳建单，重量约 45.2 吨。低于 0.5 吨才升 `Pending` |
| `resetOnly` | 第一次判稳就升 `Pending`，并清空记录与车牌缓存。状态留在已稳定，重量仍高时不再建单 |
| `restart` | 同样立刻上传，但把状态写成 `OffScale`。窗口仍稳定时，之后每个采样再来一笔 |

`resetOnly` 对应源码里的 `ResetCycle`（不改状态）。`restart` 对应「结束周期」被做成回到空磅、而重量还没下去。

## 证据包

相对本次 `runs/<yyyy-MM-ddTHHmmss>/`：

| collector | required | sink |
|-----------|----------|------|
| summary | yes | `summary.json` |
| report | yes | `report.md` |
| manifest | yes | `manifest.yaml` |

## Invoke

```powershell
powershell -ExecutionPolicy Bypass -File pipelines/graphs/materialclient/urban-busy-weighing-sim/scripts/Invoke-UrbanBusyWeighingSim.ps1
```

## 人闸 / Gate

- 最终验收：用户 `pass` / `fail`
- 道闸行保持未模拟

## 判定级别

| 级 | 谁判 |
|----|------|
| P0 运行时能启动 | cook |
| P1 八个场景已重放 | cook |
| P2 笔数、首笔重量、首笔车牌与夹具一致 | cook |
| P3 业务上能否打开开关 | **用户** |
