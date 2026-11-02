# ssh-agent（ops）

## 目的 / Goal

为 AI Agent 提供可重复的 **SSH 远程执行** 探针：用仓库本机私钥 `.local/.ssh/docker-linux-ed25519` 连到声明的主机，跑只读探测命令，并落证据包。

Goal 槽：`ops-ssh-agent`

Status: **active**

路径：`pipelines/graphs/ops/ssh-agent/`（见 [`pipelines/AGENTS.md`](../../../AGENTS.md)）

共享实现：[`pipelines/_shared/ops/ssh/`](../../../_shared/ops/AGENTS.md)

## 非目标

- 不修改 `repos/` 业务代码
- 不提交 secrets / runs / `.local/` 私钥
- 不替代 OpenSpec 与 CI
- Agent 不宣布 L3 / P3 通过
- **不**默认执行破坏性远程命令（需显式人闸 + `-AllowDestructive`）
- **不**在本 Graph 硬编码业务主机

## 配置指针

- `./config.yaml`
- `./secrets.local.yaml`（gitignore；**必填** `host` / `user`）
- `./secrets.example.yaml`
- 私钥：`.local/.ssh/docker-linux-ed25519`（gitignore；用户自行放入 / 替换）
- known_hosts：`.local/.ssh/known_hosts`（自动维护）

## 前置

1. 本机已装 **OpenSSH Client**（`ssh` 在 PATH）
2. 将私钥放到 `.local/.ssh/docker-linux-ed25519`
3. 复制 `secrets.example.yaml` → `secrets.local.yaml`，填 `host` / `user`（可选 `port`）
4. 一键探针：
   ```powershell
   powershell -ExecutionPolicy Bypass -File `
     pipelines/graphs/ops/ssh-agent/scripts/Invoke-SshAgentProbe.ps1
   ```

## Sockets

| | |
|--|--|
| Start | `ssh-idle` |
| End | `ssh-proved` |
| Cook | `new-object` |

## Context

- 指针：`secrets.local.yaml` 的 `host` / `user` / `port`；identity 见 config `target.identityRel`
- 指纹：远程 `uname` / `whoami` 输出写入证据
- 显示名：仅人读，禁止当唯一键
- 歧义（缺 host/user/密钥）：停止并问用户

## 状态机 / Cook chain

```mermaid
flowchart LR
  BindN[bind-config]
  KeyN[resolve-identity]
  CookN[ssh-remote-probe]
  ValidateN[validate-exit]
  GateN[Gate]
  BindN -->|"ssh-idle"| KeyN --> CookN -->|"ssh-proved"| ValidateN --> GateN
```

1. **bind-config** — 读 config/secrets；建 `runs/<ts>/`
2. **resolve-identity** — 校验 `.local/.ssh/docker-linux-ed25519`；可选收紧 Windows ACL
3. **ssh-remote-probe** — `Invoke-SshRemote` 执行 `target.probeCommand`
4. **validate-exit** — exitCode=0；写 summary/report
5. **Gate** — 用户验收

失败策略：`retries: 1`；`stopOnError: false`。

## 证据包

相对本次 `runs/<yyyy-MM-ddTHHmmss>/`：

| collector | required | sink |
|-----------|----------|------|
| ssh | true | `ssh/`（stdout.txt / stderr.txt / meta.json） |
| prepare | true | `prepare/identity.json` |
| summary | true | `summary.json` |
| report | true | `report.md` |

缺证仍写文件：`source: missing` / `count: 0`。

## Invoke

- 命令：`/run-pipeline ops/ssh-agent`
- 脚本（experimental）：`./scripts/Invoke-SshAgentProbe.ps1`
- 任意远程命令（共享，不经本 Graph）：
  ```powershell
  powershell -ExecutionPolicy Bypass -File pipelines/_shared/ops/ssh/Invoke-SshRemote.ps1 `
    -HostName "<host>" -User "<user>" -RemoteCommand "<cmd>"
  ```

## 人闸 / Gate

- 缺密钥 / 缺 `host`/`user`
- 探测命令像破坏性操作且未授权
- `environment` ≠ `local` 时确认
- 最终验收：用户 `pass` / `fail`

## 判定级别

| 级 | 内容 | 谁判 |
|----|------|------|
| L0 / P0 | 私钥存在；ssh 客户端可用 | Agent |
| L1 / P1 | SSH 握手成功（命令已送达远端） | Agent |
| L2 / P2 | `probeCommand` exitCode=0 且 stdout 非空 | Agent |
| L3 / P3 | 主机与业务意图匹配 | **用户** |

## Handoff

Output socket：`ssh-proved`。下游运维 Graph 可复用 `_shared/ops/ssh`，不必复制密钥路径。
