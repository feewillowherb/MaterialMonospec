---
name: /gen-ingest-pipeline
id: gen-ingest-pipeline
category: Workflow
description: Generate an ingest Graph (write external data). Artifacts only; dryRun default true
---

Pin **family=ingest**. Then follow `.cursor/commands/gen-pipeline.md` in full.

**Input**: scenario blurb. Example: `/gen-ingest-pipeline CSV upsert 到本地 SQLite`

## Extra intake (ingest)

- Source file path
- Target table/collection
- Match keys
- dryRun (default **true**)
- `stopOnError: true` recommended; retries often **0**

Default sockets: `csv-raw` (or `file-raw`) → `table-upserted`. Cook: `in-place`.

Do not invent table/column names. Writing `repos/` DBs is still ingest, not a product feature. Scripts stay under `pipelines/<slug>/scripts/` (experimental).
