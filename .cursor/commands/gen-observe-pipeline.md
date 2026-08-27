---
name: /gen-observe-pipeline
id: gen-observe-pipeline
category: Workflow
description: Generate an observe Graph under graphs/<domain>/<slug>/. Artifacts only
---

Pin **family=observe**. Then follow `.cursor/commands/gen-pipeline.md` in full.

**必读**：`pipelines/AGENTS.md`。

**Input**: scenario blurb or nothing. Example: `/gen-observe-pipeline 城管称重列表页非空壳`

## Extra intake (observe)

- Target list: id + name + path (UrbanManagement) or window/XAML pointer (MaterialClient)
- Login needed? `auth.mode`: form | none | token-header
- Evidence: screenshot + http + logs required unless user opts out a collector
- Host / `product` / `domain`: UrbanManagement vs MaterialClient — ask if unclear

Default sockets: `session-anonymous` → `observe-captured`. Cook: `new-object`.

Do not invent routes. After scaffold, ask whether to `/run-observe-pipeline <domain>/<slug>`.
