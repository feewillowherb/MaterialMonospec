# pipelines/graphs/materialclient — domain index

MaterialClient（Avalonia 称重桌面）相关验收 Graph。

约定权威：[`pipelines/AGENTS.md`](../../AGENTS.md)。本文件仅索引本 domain。

## 现行 Graph

| slug | family | goal |
|------|--------|------|
| `login-flaui` | observe | `login-observe-flaui` |
| `login-devtools` | observe | `login-observe-devtools` |
| `solidwaste-pair-ingest` | ingest | `solidwaste-missing-join-pair` |
| `recycle-wenyixilu-export` | transform | `recycle-site-db-export` |
| `waybill-softdelete-join-probe` | probe | `waybill-softdelete-join-gap` |
| `solidwaste-oct-export-include-softdelete` | transform | `solidwaste-oct-export-include-soft-masters` |
| `solidwaste-legacy-net-flag-ingest` | ingest | `solidwaste-legacy-independent-net-flag` |
| `urban-busy-weighing-sim` | transform | `urban-busy-weighing-sim` |
| `urban-stable-upload-cache-replay` | transform | `urban-stable-upload-cache-replay` |
| `urban-stable-upload-cache-probe` | probe | `urban-stable-upload-cache-probe` |
| `standard-solidwaste-schema-upgrade` | probe | `standard-solidwaste-schema-upgrade-verify` |
| `materialclient-working-db-load` | probe | `materialclient-working-db-load` |
| `fev-stable-dual-enqueue-repro` | probe | `fev-stable-dual-enqueue-repro` |
| `fev-sqlite-write-contention-repro` | probe | `materialclient-sqlite-write-contention-fev` |
| `fev-solidwaste-weigh-lpr` | probe | `fev-solidwaste-weigh-lpr` |
| `fev-solidwaste-ten-weighing-cycles` | probe | `solidwaste-ten-weighing-records` |
| `fev-solidwaste-extreme-condition` | probe | `fev-solidwaste-extreme-condition` |
| `fev-standard-weigh-waybill` | probe | `fev-standard-weigh-waybill` |

新 Graph：**MUST** 落在本目录下独立 slug；**MUST NOT** 与已有 `goal` 并存第二个 `active`。
