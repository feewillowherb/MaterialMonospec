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

新 Graph：**MUST** 落在本目录下独立 slug；**MUST NOT** 与已有 `goal` 并存第二个 `active`。
