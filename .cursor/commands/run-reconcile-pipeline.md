---
name: /run-reconcile-pipeline
id: run-reconcile-pipeline
category: Workflow
description: Run a reconcile Graph under graphs/<domain>/<slug>/; stop at human Gate
---

Pin **family=reconcile**. Then follow `.cursor/commands/run-pipeline.md`.

**必读**：`pipelines/AGENTS.md` §3。

**Input**: `domain/slug` with family reconcile.

## Reconcile Cook

1. Bind both sources; ambiguity → stop.
2. Extract excerpts using alignKey; redact secrets.
3. Write left excerpt, right excerpt, diff (required).
4. Optional screenshot is auxiliary, not a substitute for excerpts.

Agent may flag L1/L2 mismatches. L3 (which side is truth) is the user.
