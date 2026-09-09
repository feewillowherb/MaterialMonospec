# 2026-01-posted-old-q5 — 一月已提交（旧 Q5）

冻结 **浙江锦秋建材有限公司** 等在旧车载规则下已成功 POST 的车次。

| 项 | 值 |
|----|-----|
| 月份 | `2026-01` |
| 规则 | 旧 Q5：净 **19–23** / 皮 **13–14.5** / 毛 **33–37** |
| 来源 run | `sand-addbatch-submit/seeds/2026-01/source-run/2026-09-09T152356` |
| 状态摘录 | `state/submit-state.posted.jsonl`（仅 posted / smoke-posted） |
| 载荷 | `json/*.json`（待 POST 字段形；`outPhotos` 为 null） |

权威计数见同级 `manifest.json`。

## MUST

- regenerate 未提交数据时：本批 `dataNo` **原样并入**新月包；月吨位 Σnet = 保留净重 + 新生成净重
- 跳过 durable skip：submit 账本已有对应 `posted` / `smoke-posted`

## MUST NOT

- 修改本目录 JSON 内重量 / `dataNo` / `outTime`
- 再次对同一 `dataNo` 调用 `addBatch`（除非平台明确要求同键更新且单独授权）
