---
name: /run-probe-pipeline
id: run-probe-pipeline
category: Workflow
description: Run a probe Graph under graphs/<domain>/<slug>/; stop at human Gate
---

Pin **family=probe**. Then follow `.cursor/commands/run-pipeline.md`.

**必读**：`pipelines/AGENTS.md` §3。

**Input**: `domain/slug` with family probe.

## Probe Cook

1. Bind baseUrl + each endpoint from config only（或 adapters.script）。
2. Call in order; capture status, truncated body, redacted headers.
3. Compare expected status codes (L2 hint, not L3).
4. Required evidence: request-response file per endpoint, or one file with `count: 0` if none ran.
5. `environment` ≠ `local` 或破坏性写入 → 人闸确认后再 Cook。

No silent skip. No claiming the API is “业务正确”.
