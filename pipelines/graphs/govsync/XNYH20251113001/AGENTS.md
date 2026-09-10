# XNYH20251113001 — 市平台资源化厂 PointNumber 站点根

本目录按 **PointNumber** 聚合该场地的 govsync Graphs。

| Graph | Family | Goal | 说明 |
|-------|--------|------|------|
| `sand-addbatch-2026-01/` | transform | `gov-sand-product-addbatch-2026-01` | **禁止 POST**；1 月待 POST JSON + `dataNo` 台账 |
| `sand-addbatch-2026-02/` | transform | `gov-sand-product-addbatch-2026-02` | **禁止 POST**；2 月待 POST JSON + `dataNo` 台账 |
| `sand-addbatch-submit/` | probe | `gov-sand-product-addbatch-submit` | 按月读冻结源；**默认禁止自动 POST** |

| 归档 | 说明 |
|------|------|
| `preserved/2026-01-posted-old-q5/` | 一月已提交、**旧 Q5** 车次快照（勿重 POST；regenerate 时保留） |

约定：**每月独立 Graph**（独立 `goal` / slug）；submit 侧 `seeds/<yyyy-MM>/` 分仓，勿跨月混跑。

路径约定见 [`pipelines/AGENTS.md`](../../../AGENTS.md)（`graphs/govsync/<PointNumber>/<slug>/`）。

**MUST NOT** 在本目录提交 `secrets.local.yaml` / `runs/` / `out/`。

Retired：`graphs/_retired/2026-09/sand-addbatch-2026-01/`（前任实现）。
