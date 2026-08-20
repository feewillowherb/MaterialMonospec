# AI Pipelines

现行「如何再验」落在本目录，不落在日期调研夹。

哲学：`docs/2026-08-13-ai-pipeline-design-philosophy/`  
入口命令：`/gen-pipeline`、`/run-pipeline`（亦可 `/gen-<family>-pipeline`、`/run-<family>-pipeline`）

## Goal → Graph

| Goal（互斥槽） | Family | Graph slug | Status |
|----------------|--------|------------|--------|
| （尚无实例） | | | |

Retired：无。

## 约定

- 生成只写工件；执行另开 `/run-pipeline <slug>`。
- 密钥只进 `secrets.local.yaml`；`runs/` 默认不提交。
- 脚本只放 `pipelines/<slug>/scripts/`，标 `experimental`；进业务须 OpenSpec 引用本 Graph。
- 同一 Goal 最多一条 `active` Graph。
