---
name: /gen-transform-pipeline
id: gen-transform-pipeline
category: Workflow
description: Generate a transform Graph under graphs/<domain>/<slug>/. Artifacts only
---

Pin **family=transform**. Then follow `.cursor/commands/gen-pipeline.md` in full.

**必读**：`pipelines/AGENTS.md`。

**Input**: scenario blurb. Example: `/gen-transform-pipeline 导出夹具到 _tmp`

## Extra intake (transform)

- Input path
- Output path (prefer `_tmp/` or Graph 目录 — not `repos/` product output)
- Pointer to transform rules (file or documented mapping)
- `domain` / `product`（不确定则 Ask）

Default sockets: `file-raw` → `file-derived`. Cook: `new-object`.

If the user wants to write a production/shared database, switch family to **ingest**, do not stretch transform.
