---
name: /run-ingest-pipeline
id: run-ingest-pipeline
category: Workflow
description: Run an ingest Graph under graphs/<domain>/<slug>/; stop at human Gate
---

Pin **family=ingest**. Then follow `.cursor/commands/run-pipeline.md`.

**必读**：`pipelines/AGENTS.md` §3。

**Input**: `domain/slug` with family ingest.

## Ingest Cook

1. Bind source file + table; headers must include matchKeys.
2. If `dryRun: true`: count only, no writes.
3. If `dryRun: false`: confirm (always if environment ≠ local). Prefer one transaction; rollback on failure.
4. Write `summary.json` + `report.md`. Never delete rows not in source unless config says so.

Do not treat a successful upsert as L3. Ask pass/fail.
