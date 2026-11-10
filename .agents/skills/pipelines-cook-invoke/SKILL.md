---
name: pipelines-cook-invoke
description: Read the matching Graph contract before cooking a MaterialMonospec pipeline. Use when generating, selecting, or running pipelines/graphs. Does not replace the Node.js cook runtime. .NET 10 experiments follow pipelines/AGENTS.md §4.2.
---

# Cook invoke

Before generating or cooking a Graph:

1. Read `pipelines/AGENTS.md` and select by `domain` / `family` / `goal`. If more than one active Graph matches, ask. Do not guess.
2. Read the chosen `pipeline.md`, `config.yaml`, and `contract.yaml` when that file exists.
3. Read `acceptance.md` when it exists. Report cook results as P0–P3. Do not convert them to ICD levels, and do not self-declare P3.
4. Keep secrets in `secrets.local.yaml`. Do not overwrite an existing `runs/` directory.
5. A pipeline pass does not authorize a product change. Product behavior goes through OpenSpec, and pipeline-originated product changes also need Human `APPROVED`.

The default cook runtime stays Node.js, as written in `pipelines/AGENTS.md` §4. A Graph may add a `net10.0` experiment project under §4.2. This skill does not add a Python cook, does not rewrite existing TypeScript cooks into C#, and does not require Socket / Wire / Context on graphs that do not already declare them.
