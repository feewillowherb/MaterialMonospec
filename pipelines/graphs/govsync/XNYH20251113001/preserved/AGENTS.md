# preserved — 已提交旧规则快照

本目录存放 **XNYH20251113001** 已成功上报、且仍属 **旧 Q5 车载规则** 的冻结车次，供 regenerate-pending 时对照保留。

| 子目录 | 内容 |
|--------|------|
| `2026-01-posted-old-q5/` | 2026-01 已 `posted` / `smoke-posted` 的旧规则 JSON + 状态摘录 |

## MUST

- 重拆未提交吨位时：**保留**本目录中的 `dataNo` / 重量 / 时间，不得改写或重 POST
- 归档后更新同级子目录 `manifest.json` 与站点根 `AGENTS.md` 索引

## MUST NOT

- 把本目录当作 submit Graph 的 `source-run` 输入
- 提交 `secrets.local.yaml` / 全量 `runs/` 到本树
- 用 `README.md` 作说明入口（见 `traits/agents-md-only-trait.md`）

重抽脚本（一次性）：`_extract-posted-old-q5.mjs`（从 submit seeds + state 再导出）。
