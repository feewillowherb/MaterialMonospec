# pipelines/_shared/ops — 运维共享工具

供 AI Agent 与 `graphs/ops/*` 复用的运维基础设施。  
验收 Graph 落在 `pipelines/graphs/ops/<slug>/`；本目录只放可复用脚本。

## SSH（本目录主能力）

| 路径 | 用途 |
|------|------|
| `ssh/Resolve-SshIdentity.ps1` | 解析仓库根 `.local/.ssh/docker-linux-ed25519`，校验存在，可选收紧 Windows ACL |
| `ssh/Unlock-SshIdentity.ps1` | 口令私钥 → 临时 `.batch` 无口令副本（cook 后删除）；规避本机 ssh-agent Disabled |
| `ssh/Invoke-SshRemote.ps1` | 用该私钥执行远程命令并可选落证据 |
| `ssh/Copy-ScpToRemote.ps1` | 用该私钥 scp 上传文件到已存在的远端目录；证据记录文件名、大小、sha256 |

### 密钥约定（NON-NEGOTIABLE）

| 项 | 值 |
|----|-----|
| 私钥 | `.local/.ssh/docker-linux-ed25519`（相对仓库根） |
| 公钥（可选） | `.local/.ssh/docker-linux-ed25519.pub` |
| known_hosts | `.local/.ssh/known_hosts` |
| gitignore | `.local/*` 不提交，仅 `.local/AGENTS.md` 跟踪；**用户自行放入 / 替换私钥** |

- **MUST NOT** 把私钥 / 公钥提交进 Git。
- **MUST NOT** 在 `pipeline.md` / `config.yaml` / 本文件写真实主机密码。
- 主机、用户、端口来自调用参数、Graph 的 `secrets.local.yaml`，或 Graph 对仓库根 `.local/` 的路径引用。
- 需要重复执行的部署做成 `graphs/ops/<slug>/`。Graph 可以用路径引用 `.local/` 里的密钥。

### Agent 调用（共享）

```powershell
# 校验密钥
powershell -ExecutionPolicy Bypass -File pipelines/_shared/ops/ssh/Resolve-SshIdentity.ps1

# 远程命令（host/user 必填；勿编造）
powershell -ExecutionPolicy Bypass -File pipelines/_shared/ops/ssh/Invoke-SshRemote.ps1 `
  -HostName "<host>" -User "<user>" -RemoteCommand "uname -a"
```

验收探针 Graph：

| Graph | Goal | 用途 |
|-------|------|------|
| `graphs/ops/ssh-agent/` | `ops-ssh-agent` | SSH 连通性冒烟 |
| `graphs/ops/fev-u1-host/` | `ops-fev-u1-host` | FEV U1 宿主 OS/虚拟化采证 |
| `graphs/ops/fev-u2-docker/` | `ops-fev-u2-docker` | FEV U2 安装 Docker Engine + MSSQL 容器验证 |
| `graphs/ops/fev-u10-uploads-smb/` | `ops-fev-u10-uploads-smb` | FEV U10 虚拟机经 SMB 共用 IIS Uploads（reach / mount-test） |
| `graphs/ops/deploy-urban-acceptance/` | `ops-deploy-urban-acceptance` | UrbanManagement Phase 1 部署到虚拟机 `5333` 并验证（ssh + scp） |
| `graphs/ops/deploy-urban-lab-138/` | `ops-deploy-urban-lab-138` | 实验口 138 的八服务镜像发布（ssh + scp；`deploy` 需 `-Apply`） |

密码认证是可选项：调用方把密码传给 `-Password`。helper 用临时 `SSH_ASKPASS` 交给子进程，不把密码写入命令行、askpass 文件、日志或证据，用完删除临时目录并清掉环境变量。没有 `-Password` 时仍只用 `.local/.ssh/docker-linux-ed25519`。

## MUST / MUST NOT

- **MUST** 默认 `BatchMode=yes`、`IdentitiesOnly=yes`；只用声明的 identity 文件。
- **MUST** 把远程命令视为有副作用：破坏性操作前走人闸；探针默认只读命令。
- **MUST NOT** 在共享脚本里硬编码业务主机 IP / 域名。
- 新 ops 共享工具落本目录子夹；新验收 Graph 落 `graphs/ops/`。
