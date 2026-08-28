---
name: /run-observe-pipeline
id: run-observe-pipeline
category: Workflow
description: Run an observe Graph under graphs/<domain>/<slug>/; stop at human Gate
---

Pin **family=observe**. Then follow `.cursor/commands/run-pipeline.md`.

**必读**：`pipelines/AGENTS.md` §3。

**Input**: `domain/slug` 或 slug。If omitted, list `graphs/**` where `graph.family` / `family` is observe.

## Observe Cook

1. Resolve host from config (UrbanManagement vs MaterialClient).
2. Install collectors (screenshot/http/logs) **before** navigate or attach.
3. Auth only via config.auth; missing credentials → Gate.
4. Per step: Bind → wait readySelector/timeout → capture → flush.
5. `stopOnError: false` default: record failure, continue remaining steps.

Required sinks must exist even if empty. End: 等待用户验收. Next is not OpenSpec unless user asks.
