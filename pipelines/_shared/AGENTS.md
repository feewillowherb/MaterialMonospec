# pipelines/_shared — Agent 约定

跨 Graph 复用的 cook adapters / runbooks。  
相对 Graph 深度：`graphs/<domain>/<slug>/` → `../../../_shared/...`

约定权威：[`pipelines/AGENTS.md`](../AGENTS.md)。本文件只索引共享片段。

## 索引

| 路径 | 用途 |
|------|------|
| `ops/` | 运维基础设施（SSH 等）；见 [`ops/AGENTS.md`](ops/AGENTS.md) |
| `ops/ssh/Invoke-SshRemote.ps1` | Agent 远程 SSH 执行（密钥默认 `.local/.ssh/docker-linux-ed25519`）；密码等机密只能走 `-StdinText`（不进命令行、日志与证据） |
| `ops/ssh/Copy-ScpToRemote.ps1` | Agent scp 上传（同一私钥与 known_hosts） |
| `ops/ssh/Resolve-SshIdentity.ps1` | 解析 / 校验本机 SSH 私钥与 known_hosts |
| `ops/ssh/Unlock-SshIdentity.ps1` | 口令私钥临时解锁为 `.batch`（用完删除） |
| `urban/Invoke-UrbanLprSeedSettings.ps1` | MaterialClient.Urban 诊断口：GET/POST Settings，**完全替换** `licensePlateRecognitionConfigs` |
| `urban/Invoke-UrbanLicenseSeed.ps1` | 授权初始化：写入 `license.urban` + `upsert-license-info`（或 POST `/api/license/seed`） |
| `urban/seeds/demo-license.json` | 默认演示授权种子 |
| `urban/tools/upsert-license-info/` | 本地 SQLite upsert（Node/TS；需 Node ≥ 22.5） |
| `evidence/` | Run identity / manifest 约定；见 [`evidence/AGENTS.md`](evidence/AGENTS.md) |
| `../package.json` | pipelines Node workspace（`node_modules/` 已 gitignore） |

## MUST / MUST NOT

- **MUST** 把跨 Graph 复用逻辑放本目录；**MUST NOT** 在各 Graph 内复制粘贴登录 / SSH / seed 逻辑。
- **MUST NOT** 把密钥、私钥、密码写入本目录任何已跟踪文件。
- 共享 Node 工具 **MUST** 挂 `pipelines/` 根 `package.json`；**MUST NOT** 为单工具另建 `package.json`。
- 目录说明入口是本 `AGENTS.md`；**MUST NOT** 用 `README.md`。
