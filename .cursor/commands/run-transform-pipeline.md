---
name: /run-transform-pipeline
id: run-transform-pipeline
category: Workflow
description: Run a transform Graph under graphs/<domain>/<slug>/; stop at human Gate
---

Pin **family=transform**. Then follow `.cursor/commands/run-pipeline.md`.

**必读**：`pipelines/AGENTS.md` §3。

**Input**: `domain/slug` with family transform.

## Transform Cook

1. Bind input file; refuse if path missing.
2. Cook to declared output only (local). Record input hash, output path, byte/line counts.
3. Optional sample preview in the run directory.
4. Do not write production DBs or `repos/` app data directories unless config + user Gate said so (then it was probably ingest).

Ask pass/fail on the derived file.
