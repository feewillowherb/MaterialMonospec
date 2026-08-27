---
name: /gen-probe-pipeline
id: gen-probe-pipeline
category: Workflow
description: Generate a probe Graph under graphs/<domain>/<slug>/. Artifacts only
---

Pin **family=probe**. Then follow `.cursor/commands/gen-pipeline.md` in full.

**必读**：`pipelines/AGENTS.md`。

**Input**: scenario blurb. Example: `/gen-probe-pipeline UrbanManagement 健康检查与激活 API`

## Extra intake (probe)

- Endpoint list (method + path or full URL)
- Expected status codes
- Auth: none | token-header | other (secretsKeys only)
- baseUrl from user or source; **do not invent**
- `domain` / `product`（不确定则 Ask）

Default sockets: `endpoint-idle` → `probe-recorded`. Cook: `new-object`.

Typical hosts here: UrbanManagement App, BasePlatform via UrbanManagement client, government outbound (`govsync`). Probe is usually read-only; destructive POST（如 save）须在 config 标明人闸。
