---
name: /gen-transform-pipeline
id: gen-transform-pipeline
category: Workflow
description: Generate a transform Graph (A→B locally). Artifacts only; no production DB writes
---

Pin **family=transform**. Then follow `.cursor/commands/gen-pipeline.md` in full.

**Input**: scenario blurb. Example: `/gen-transform-pipeline 导出夹具到 _tmp`

## Extra intake (transform)

- Input path
- Output path (prefer `_tmp/` or `pipelines/<slug>/` — not `repos/` product output)
- Pointer to transform rules (file or documented mapping)

Default sockets: `file-raw` → `file-derived`. Cook: `new-object`.

If the user wants to write a production/shared database, switch family to **ingest**, do not stretch transform.
