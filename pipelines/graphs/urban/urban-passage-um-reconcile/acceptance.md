# Acceptance — urban-passage-um-reconcile

Status: **active**（Graph `graph.status: active`；L3 由用户在 run `2026-09-01T163853` 确认 pass）

Agent 不得将本文件改为通过。用户回复 `pass` / `fail` 后，只改**本次 run** 下的副本。

| 项 | 值 |
|----|-----|
| run | |
| L0 | pending |
| L1 | pending |
| L2 | pending |
| L3 | pending（仅用户） |
| 对象 | MaterialClient passage seed ↔ UrbanManagement ingest/list |
| OpenSpec | update-urban-passage-client-upload-reconcile |
| 原因 | |

### 验收提示

- L0：`GET` 卡口/成品 list API 返回 2xx
- L1（ClientUpload）：probe 10 条 test-passage accepted；客户端 IUrbanPassageUploadService 上云
- L2：`reconcile/plate-match.json` 无 missing 车牌（卡口 5 + 成品 5）
- L3：UM `/checkpoint-passage`、`/finished-product-passage` 可见；可选 Gov 出站 — **仅用户**
