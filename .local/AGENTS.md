# .local — 本机密钥

本目录只保管**本机密钥与凭据**。人与 Agent 的目录入口是本文件。

与根 [`AGENTS.md`](../AGENTS.md) 冲突时，本目录以**更严格**者为准：这里不写脚本、不放一次性探针、不放部署包。

## 职责

允许留下的只有本机秘密材料，例如：

- SSH 私钥与 `known_hosts`（运维图默认私钥：`.ssh/docker-linux-ed25519`，由用户自行替换）
- 主机口令、连接串、本机 `appsettings` 密钥副本
- 已有凭据文件（如 `urbanmanagement-docker-138.yaml`、`urbanmanagement-fdsoft-sso.json`）

各图自己的 `secrets.local.yaml` 仍然可用。口令原文留在本目录或该文件里。

## 重复执行

部署、发布，以及还会再跑的探测与验收，**MUST** 做成 Graph：`pipelines/graphs/<domain>/<slug>/`。先按 [`pipelines/AGENTS.md`](../pipelines/AGENTS.md) 选型；没有命中再新建。

这类 Graph **可以**用路径引用本目录里的密钥，只写路径，例如：

- `identityRel: .local/.ssh/docker-linux-ed25519`
- `secretsRef` 指向本目录下的凭据文件（相对仓库根）

**MUST NOT** 把会再执行的脚本放在本目录，或放在 `pipelines/graphs/.local/`。

## MUST

- 新建或读取本目录前先读本文件。
- 口令、私钥、连接串只留在本目录（或 Graph 的 `secrets.local.yaml`）。**MUST NOT** 把内容写进可提交文件，也 **MUST NOT** 在对话、`proposal.md`、`docs/` 里粘贴原文。
- 除本 `AGENTS.md` 外，本目录内容保持不提交。`.gitignore` 为 `.local/*`，仅本文件被例外跟踪。`pipelines/graphs/.local/` 同样不提交。

## MUST NOT

- **MUST NOT** 在本目录编写或留下脚本与临时代码：`.py`、`.ps1`、`.sh`、`.mjs`、`.ts`、`.cs`、`Dockerfile`、控制台实验工程、`bin/`、`obj/`。
- **MUST NOT** 把一次性探针、远程拉取的 compose、构建日志、`.tgz` / 镜像上下文、HTML 抓页放在这里。
- **MUST NOT** 用本目录当草稿区、实验区或部署工作目录。

脚本放哪：

| 需要 | 位置 |
|------|------|
| 部署、发布、还会再跑的探测与验收 | `pipelines/graphs/<domain>/<slug>/`；密钥路径可指向本目录 |
| 仓库校验、构建、发布入口 | [`scripts/AGENTS.md`](../scripts/AGENTS.md) |
| 某条 Graph 的 cook / invoke | 该 Graph 的 `scripts/` |
| 跨 Graph 复用 | `pipelines/_shared/` |

## 非目标

- 不在此目录落盘 `README.md`
- 不把产品行为、OpenSpec 工件或可复用调研写进本目录
