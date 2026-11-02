# pipelines/graphs/urban — domain index

UrbanManagement 相关验收 Graph。

约定权威：[`pipelines/AGENTS.md`](../../AGENTS.md)。本文件只索引本 domain。

## 现行 Graph

| slug | family | goal |
|------|--------|------|
| `urban-passage-probe` | probe | `urban-passage-lpr-probe` |
| `urban-license-probe` | probe | `urban-license-seed-probe` |
| `urban-passage-um-reconcile` | reconcile | `urban-passage-client-um-reconcile` |
| `urban-db-accesscode-migrate` | probe | `urban-sqlite-accesscode-migrate-verify` |
| `urban-signalr-online-probe` | probe | `urban-signalr-online-probe` |

新 Graph 落在本目录下独立 slug。同一 `goal` 不得有第二条 `active` Graph。

`baseplatform` 与 `platform` 尚无 Graph 目录。出现第一条 Graph 时再补该 domain 的 `AGENTS.md`。
