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
| `deploy-urban-acceptance` | ingest | `ops-deploy-urban-acceptance`（**切流后 = 日常正式发版**；默认 `deployProfile=production`：允许 worker GovSync；宿主探针 **仅 5233**（不再用 5333）；`acceptance` 为关同步干跑；`deploy` 需 `-Apply`，`-ResetDatabase` 另需人闸；`verify` 只读） |
| `deploy-urban-lab-138` | ingest | `ops-deploy-urban-lab-138`（实验口 138；`publish` 只在本机打包；`deploy` 需 `-Apply`；不替换宿主机 compose / `.env`；`verify` 只读 5333 与 5334） |
| `deploy-recycle-web-lab-138` | ingest | `ops-deploy-recycle-web-lab-138`（实验口 138，**只发 Recycle Web**；其余七个服务不动；`deploy` 需 `-Apply`；带新 EF migration 时加 `-WithMigrator`；`verify` 只读 5334） |
| `cutover-safety-drill` | probe | `ops-cutover-safety-drill`（回滚导出 MSSQL → SQLite；生产库只读） |
| `e2e-urban-phase2` | probe | `ops-e2e-urban-phase2`（合成客户端经 `5333` 跑客户端契约与 backplane；写入探针数据并清理） |
| `urban-cutover` | ingest | `ops-urban-cutover`（**2026-11-04 正式口已切入**；`check` 只读；`cutover` 需 `-Apply` 仅复盘/补做；日常发版用 `deploy-urban-acceptance`） |

新 Graph **MUST** 落在本目录下独立 slug；**MUST NOT** 与已有 `goal` 并存第二个 `active`。

## 密钥

私钥默认：仓库根 `.local/.ssh/docker-linux-ed25519`（由用户自行替换）。需要重复执行的部署做成 `graphs/ops/<slug>/`，密钥引用可以指向仓库根 `.local/`。约定见 [`.local/AGENTS.md`](../../../.local/AGENTS.md)。除该 `AGENTS.md` 外，`.local/` 内容不提交。
