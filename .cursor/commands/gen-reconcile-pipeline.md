---
name: /gen-reconcile-pipeline
id: gen-reconcile-pipeline
category: Workflow
description: Generate a reconcile Graph under graphs/<domain>/<slug>/. Artifacts only
---

Pin **family=reconcile**. Then follow `.cursor/commands/gen-pipeline.md` in full.

**必读**：`pipelines/AGENTS.md`。

**Input**: scenario blurb. Example: `/gen-reconcile-pipeline 客户端称重记录 vs UrbanManagement`

## Extra intake (reconcile)

- Left source (path, query, or page pointer)
- Right source
- Align key
- Secrets for each source (key names only)
- `domain` / `product`（不确定则 Ask）

Default sockets: `left-excerpt` + `right-excerpt` → `reconcile-diffed`. Cook: `new-object`.

Do not hide SQL/API inside an observe Graph. If the user also wants screenshots, that is a **second** observe Graph, wire after this Gate.
