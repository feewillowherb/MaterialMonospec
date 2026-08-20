---
name: /gen-observe-pipeline
id: gen-observe-pipeline
category: Workflow
description: Generate an observe Graph (UI/surface evidence). Artifacts only; then /run-observe-pipeline
---

Pin **family=observe**. Then follow `.cursor/commands/gen-pipeline.md` in full.

**Input**: scenario blurb or nothing. Example: `/gen-observe-pipeline 城管称重列表页非空壳`

## Extra intake (observe)

- Target list: id + name + path (UrbanManagement) or window/XAML pointer (MaterialClient)
- Login needed? `auth.mode`: form | none | token-header
- Evidence: screenshot + http + logs required unless user opts out a collector
- Host: UrbanManagement (Playwright) vs MaterialClient (Avalonia DevTools) — ask if unclear

Default sockets: `session-anonymous` → `observe-captured`. Cook: `new-object`.

Do not invent routes. After scaffold, ask whether to `/run-observe-pipeline <slug>`.
