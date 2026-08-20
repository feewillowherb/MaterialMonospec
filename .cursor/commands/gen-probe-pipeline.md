---
name: /gen-probe-pipeline
id: gen-probe-pipeline
category: Workflow
description: Generate a probe Graph (HTTP/API/health). Artifacts only; read-only calls
---

Pin **family=probe**. Then follow `.cursor/commands/gen-pipeline.md` in full.

**Input**: scenario blurb. Example: `/gen-probe-pipeline UrbanManagement 健康检查与激活 API`

## Extra intake (probe)

- Endpoint list (method + path or full URL)
- Expected status codes
- Auth: none | token-header | other (secretsKeys only)
- baseUrl from user or source; **do not invent**

Default sockets: `endpoint-idle` → `probe-recorded`. Cook: `new-object`.

Typical hosts here: UrbanManagement App, BasePlatform via UrbanManagement client. Probe is read-only; writes belong to ingest or an OpenSpec change.
