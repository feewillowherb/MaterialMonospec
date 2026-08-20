---
name: /gen-reconcile-pipeline
id: gen-reconcile-pipeline
category: Workflow
description: Generate a reconcile Graph (two truths vs align key). Artifacts only
---

Pin **family=reconcile**. Then follow `.cursor/commands/gen-pipeline.md` in full.

**Input**: scenario blurb. Example: `/gen-reconcile-pipeline 客户端称重记录 vs UrbanManagement`

## Extra intake (reconcile)

- Left source (path, query, or page pointer)
- Right source
- Align key
- Secrets for each source (key names only)

Default sockets: `left-excerpt` + `right-excerpt` → `reconcile-diffed`. Cook: `new-object`.

Do not hide SQL/API inside an observe Graph. If the user also wants screenshots, that is a **second** observe Graph, wire after this Gate.
