---
name: /gen-pipeline
id: gen-pipeline
category: Workflow
description: Generate an AI pipeline Graph (artifacts only) from a scenario; family observe|ingest|probe|reconcile|transform
---

Generate a **repeatable AI pipeline** under `pipelines/<slug>/`. **Do not run it.** Same split as OpenSpec propose vs apply.

**Input**: family id, a blurb, or nothing. Example: `/gen-pipeline observe 城管称重列表非空壳`

---

## Must read (in order)

1. `docs/2026-08-13-ai-pipeline-design-philosophy/05-快速参考.md`
2. `docs/2026-08-13-ai-pipeline-design-philosophy/03-生成协议.md`
3. `docs/2026-08-13-ai-pipeline-design-philosophy/02-本体与工件契约.md`
4. Sockets / Goal 互斥 / 拆文：`06-图模型与成文约定.md`
5. Conflict → `01-指导哲学.md`
6. **Do not** copy Acme sample URLs/tables from `04` into this repo.

---

## Guardrails

- Write artifacts only. User must say run / 「立即执行」 before `/run-pipeline`.
- Never invent routes, table names, selectors, accounts, env URLs.
- Never put secrets in markdown or `config.yaml`.
- Do not edit `repos/` to make a pipeline easier.
- Scripts only in `pipelines/<slug>/scripts/`, marked `experimental`.
- `pipelines/<slug>/` exists → Ask: overwrite / new slug / cancel.
- Same Goal already has `active` Graph → Ask: retire old / new Goal / cancel.
- `environment` ≠ `local` → confirm before finishing generate.

---

## This repo

| Host | Typical family | Bind / adapter |
|------|----------------|----------------|
| UrbanManagement (Blazor) | observe, probe | Playwright MCP；指针 = baseUrl + path（用户给或从代码读，不编造） |
| MaterialClient (Avalonia) | observe | Avalonia DevTools MCP（attach-to-app / attach-to-file）；不编造窗口名当唯一键 |
| UrbanManagement / BasePlatform HTTP | probe | endpoint 列表必须来自用户或源码 |
| SQLite / CSV | ingest, reconcile | 表名、匹配键、源路径必须来自用户或源码 |
| 本地文件 | transform | 输入输出路径必须来自用户 |

Mixed 「又导入又看页」→ **two Graphs** (different Goals), not one slug.

---

## Steps

1. **Intake** — extract purpose/Goal, family, slug, target/Context, success (L0+), replace-old-Graph. Ask missing required fields once. Family extras: see `03` §1.2.

2. **Classify and restate** using the template in `05`「对用户开口的复述模板」. If family was not given, pick the **smaller-side-effect** family and confirm.

3. **Fill brief** (internal or `design-brief.md`). No scaffold until brief is complete.

4. **Scaffold**
   - Template: `pipelines/_templates/<family>/` if present, else `pipelines/_template/`.
   - Create `pipelines/<slug>/` with `pipeline.md`, `config.yaml`, `secrets.example.yaml`, `acceptance.md`.
   - Replace `{{slug}}` `{{goal}}` `{{socket_*}}` `{{cook}}`. No leftover `{{`.
   - Optional `design-brief.md`. Optional `runs/.gitkeep`. No real run files.
   - If user gave secrets: `secrets.local.yaml` (gitignored) and remind not to commit.
   - Align runbook steps 1:1 with `config.yaml`.
   - mermaid Cook chain with Socket labels.
   - Update `pipelines/README.md` Goal → Graph index; move retired rows.

5. **Quality gate** — `03` §8. Fail → fix or ask; do not ship a half Graph.

6. **Summary** — slug, family, paths, step count, secrets on disk?, required collectors, next command `/run-pipeline <slug>`. Ask: **是否立即执行？** Do not start run unless yes.

---

## Forbidden

Invent targets · passwords in md · overwrite old runs · silent missing evidence · Agent L3 pass · scripts in `repos/` · Sample fake defaults · two active Graphs for one Goal · display-name as sole Context
