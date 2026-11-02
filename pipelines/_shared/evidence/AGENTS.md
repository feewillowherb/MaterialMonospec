# pipelines/_shared/evidence

一次 cook 的稳定身份与清单字段。本目录不执行 cook，也不读取密钥。

## Run identity

引用一次 Run 时使用这些字段，而不是把日志贴进 DOCS 或 OpenSpec：

| 字段 | 要求 |
|------|------|
| `graphId` | `config.yaml` 的 `id` |
| `graphPath` | 仓库相对路径，如 `pipelines/graphs/<domain>/<slug>` |
| `runId` | `runs/<yyyy-MM-ddTHHmmss>` 的目录名 |
| `result` | `pass` / `fail` / `blocked` / `unknown` |

可选：`gitRevision`、`contractPath`、证据文件的仓库相对路径。

## Manifest

新的 Run 若写清单，字段与 `manifest.example.yaml` 一致。清单不得包含密码、token、连接串或本机绝对路径。已有 `runs/` 不回填。

## Acceptance

解释证据用 P0–P3，见 `traits/pipelines-trait.md`。P3 只由用户判定。
