# pipelines/graphs/ops — domain index

运维基础设施验收 Graph（SSH 等）。跨图复用脚本在 [`pipelines/_shared/ops/`](../../_shared/ops/AGENTS.md)。

约定权威：[`pipelines/AGENTS.md`](../../AGENTS.md)。本文件只索引本 domain。

## 现行 Graph

| slug | family | goal |
|------|--------|------|
| `ssh-agent` | probe | `ops-ssh-agent` |
| `fev-u1-host` | probe | `ops-fev-u1-host` |
| `fev-u2-docker` | probe | `ops-fev-u2-docker`（安装类模式需 `-Apply`；远端需免密 sudo） |
| `fev-u10-uploads-smb` | probe | `ops-fev-u10-uploads-smb`（`reach` / `mount-test` 只读；`setup` 需 `-Apply`；写入测试需 `-ProductionWrite`） |
| `deploy-urban-acceptance` | ingest | `ops-deploy-urban-acceptance`（`deploy` 需 `-Apply`，`-ResetDatabase` 另需人闸；`verify` 只读） |

新 Graph **MUST** 落在本目录下独立 slug；**MUST NOT** 与已有 `goal` 并存第二个 `active`。

## 密钥

私钥默认：仓库根 `.local/.ssh/docker-linux-ed25519`（`.local/` 已 gitignore；由用户自行替换）。
