---
name: /run-pipeline
id: run-pipeline
category: Workflow
description: Execute an existing pipelines/graphs/<domain>/<slug> Graph; collect evidence; stop at human Gate
---

Run an **existing** Graph at `pipelines/graphs/<domain>/<slug>/`（或遗留平铺）。**Do not invent config.** Same split as OpenSpec apply vs propose.

**必读**：`pipelines/AGENTS.md`（选型算法 §3）。

**Input**: `domain/slug` 或 slug。Example: `/run-pipeline govsync/postweight`  
If omitted: 按 AGENTS.md 选型；仍歧义则列出 `graphs/<domain>/*`（及遗留平铺）并 Ask。

Announce: `Running pipeline: <domain>/<slug>`（或遗留路径）。

---

## Must read

- This Graph’s `pipeline.md` + `config.yaml` (source of truth)；有 `graph.*` 时校验 `status: active`
- `pipelines/AGENTS.md` §3
- Skeleton: `docs/2026-08-13-ai-pipeline-design-philosophy/02-本体与工件契约.md` §5
- Gates: `05-快速参考.md` 人闸清单
- If artifacts missing or still contain `{{` → stop; tell user to `/gen-pipeline` first

---

## Guardrails

- Do not modify `repos/` or OpenSpec specs to “make the run pass”.
- Do not overwrite an old `runs/` directory. Always `runs/<yyyy-MM-ddTHHmmss>/` (local time).
- Do not mark L3 / acceptance as passed. Report stays **等待用户验收，尚未通过。**
- Missing secrets / ambiguous Context / unknown URL-table-field → Ask; do not guess.
- `environment` ≠ `local` → confirm before Cook.
- ingest and `dryRun: false` → confirm writes.
- Required collector with no data → still write file (`source: missing` / `count: 0`).
- Redact password, connection string, token, Authorization, Cookie in evidence.
- Retry cap default 2 unless config says otherwise (ingest writes often 0).

---

## This repo adapters (Cook only; still follow config)

| family | How to Cook here |
|--------|------------------|
| observe + UrbanManagement | Playwright MCP：先装 collector，再 navigate；登录只走 config.auth |
| observe + MaterialClient | Avalonia DevTools MCP attach-to-app / attach-to-file；截图进本次 run |
| probe | HTTP 按 config（或 adapters.script）；全文截断+脱敏 |
| ingest | 先 dryRun 计数；写库须事务/可回滚或 config 已声明不可回滚 |
| reconcile | 两侧摘录 + diff；不要把 SQL 偷偷塞进 observe |
| transform | 只写声明的本地 output（`_tmp/` 或 Graph 下），不写生产库 |

---

## State machine

```text
init → resolve_path → load_config → resolve_secrets → Bind/preflight
    → Cook/execute → Validate+evidence → write_report
    → Gate/await_user_acceptance → end
```

0. **resolve_path** — `pipelines/AGENTS.md` §3；0 或 >1 命中 → Ask。
1. **load_config** — family, sockets, steps, collectors. Placeholder `{{` → abort.
2. **resolve_secrets** — `secrets.local.yaml` or ask. Keys only those in brief/config.
3. **Bind** — Context order: marker → fingerprint → explicit pointer → display name (never sole key). Ambiguity → stop.
4. **Cook** — install collectors **before** actions. Execute family steps. Honor `stopOnError`.
5. **Validate** — L0/L1/L2 heuristics from config.expect; never self-pass L3.
6. **write_report** — `runs/<ts>/report.md` + copy `acceptance.md` as pending. Link evidence. Agent self-score L0–L2 only.
7. **Gate** — Ask: `请验收：pass / fail + 对象与原因。` Until reply, do not edit acceptance to passed.

On user **pass** / **fail**: write only this run’s `acceptance.md`. Do not rewrite Graph 根 `acceptance.md` as the canonical pass.

---

## Run directory (minimum)

```text
pipelines/graphs/<domain>/<slug>/runs/<yyyy-MM-ddTHHmmss>/
  report.md
  acceptance.md
  <collector sinks…>
```

---

## Forbidden

Chat-as-pipeline with no artifacts · covering previous run · silent skip · announcing 验收通过 · committing secrets/runs · mixing a second Goal’s protocol into this slug
