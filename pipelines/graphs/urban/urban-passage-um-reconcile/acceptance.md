# Acceptance — urban-passage-um-reconcile

Status: **active**（Graph `graph.status: active`。历史 run `2026-09-01T163853` 的用户确认对应 P3，不回写该 run 目录）

刻度为 Pipeline **P0–P3**。`config.yaml` 的 `expect.level` L0–L2 仍供现有 cook 读取，分别对应 P0–P2。旧的「仅用户 L3」对应 P3。Agent 不得把 P 级写成 ICD 等级，也不得将本文件改为通过。用户回复 `pass` / `fail` 后，只改**本次 run** 下的副本。

| 项 | 值 |
|----|-----|
| run | |
| P0 | pending |
| P1 | pending |
| P2 | pending |
| P3 | pending（仅用户） |
| 对象 | MaterialClient passage seed ↔ UrbanManagement ingest/list |
| OpenSpec | update-urban-passage-client-upload-reconcile |
| 原因 | |

### 验收提示

- P0：`GET` 卡口/成品 list API 返回 2xx
- P1（ClientUpload）：probe 10 条 test-passage accepted；客户端 IUrbanPassageUploadService 上云
- P2：`reconcile/plate-match.json` 无 missing 车牌（卡口 5 + 成品 5）
- P3：UM `/checkpoint-passage`、`/finished-product-passage` 可见；可选 Gov 出站 — **仅用户**
