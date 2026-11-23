# Acceptance — fev-standard-weigh-waybill

Status: **pending**

Agent 不得将本文件改为通过。用户回复 `pass` / `fail` 后，只改本次 run 下的副本。

| 项 | 值 |
|----|----|
| run | |
| P0 | pending |
| P1 | pending |
| P2 | pending |
| P3 | pending（仅用户） |
| 对象 | MaterialClient Standard：测试 API 车牌 + 重车/轻车 → WeighingMode=0 的 Waybill |
| 原因 | |

P0–P2 由 cook 写入该次 `runs/` 的 `summary.json`。P3 不由 Agent 填写。  
`fevVerdict: FEASIBLE` 只回答「测试 API 能否配出一条 Standard Waybill」；不是 Capability 交付。
