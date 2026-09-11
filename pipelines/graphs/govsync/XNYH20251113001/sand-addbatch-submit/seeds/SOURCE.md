# sand-addbatch-submit seeds — 按月分仓（分开执行）

每月一份冻结 transform 产物，**互不混跑**。切换月份时改 `config.yaml` 的 `source.month` / `runDirRel` / `durableStateRel`。

| 月份 | 目录 | 状态 |
|------|------|------|
| 2026-01 | `seeds/2026-01/` | **active** — run `2026-09-09T165250` |
| 2026-02 | `seeds/2026-02/` | **active** — run `2026-09-10T143827` |
| 2026-03 | `seeds/2026-03/` | **active** — run `2026-09-10T221030` |
| 2026-04 | `seeds/2026-04/` | **active** — run `2026-09-11T090524` |
| 2026-05 | `seeds/2026-05/` | **active** — run `2026-09-11T133554` |

布局约定：

```text
seeds/<yyyy-MM>/
  SOURCE.md                 # 本月指针
  source-run/<runId>/       # 冻结 json/ + ledger + submit-meta
```

执行态（gitignore）：`state/<yyyy-MM>/submit-state.jsonl` — 与月份对齐，避免跨月误 skip。
