---
name: /run-probe-pipeline
id: run-probe-pipeline
category: Workflow
description: Run a probe Graph; record request/response (redacted); stop at human Gate
---

Pin **family=probe**. Then follow `.cursor/commands/run-pipeline.md`.

**Input**: slug with family probe.

## Probe Cook

1. Bind baseUrl + each endpoint from config only.
2. Call in order; capture status, truncated body, redacted headers.
3. Compare expected status codes (L2 hint, not L3).
4. Required evidence: request-response file per endpoint, or one file with `count: 0` if none ran.

No silent skip. No claiming the API is “业务正确”.
