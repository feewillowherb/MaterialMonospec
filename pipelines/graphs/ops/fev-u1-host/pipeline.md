# fev-u1-host（ops）

## 目的 / Goal

用 [`pipelines/_shared/ops`](../../../_shared/ops/AGENTS.md) SSH 工具，对目标机采集 **FEV U1** 证据：主机 OS / 是否虚拟化 / 虚拟化能力线索。

蓝图定义见 [`docs/2026-11-02-urbanmanagement-docker-mssql-upgrade/05-部署与切换回滚.md`](../../../../docs/2026-11-02-urbanmanagement-docker-mssql-upgrade/05-部署与切换回滚.md) §1 **U1**。

Goal 槽：`ops-fev-u1-host`

Status: **active**

路径：`pipelines/graphs/ops/fev-u1-host/`

## 非目标

- 不修改 `repos/` 业务代码
- 不提交 secrets / runs / `.local/` 私钥
- 不替代 OpenSpec；**不**把 Pipeline pass 写成产品 `FEASIBLE` 定案
- 不跑 U2–U9（另开 Graph / 另次实验）
- 不执行破坏性远程命令
- **U1 证据解读与 FEV Verdict 由 Agent 完成**（人不再做 OS/virt 分析）；本 Verdict 只回答宿主可行性，**不是**产品交付或 OpenSpec 授权

## 配置指针

- `./config.yaml`
- `./secrets.local.yaml`（gitignore；host / user / port / 可选 identityPassphrase）
- `./secrets.example.yaml`
- 共享 SSH：`pipelines/_shared/ops/ssh/`
- 私钥：`.local/.ssh/docker-linux-ed25519`

## 前置

1. OpenSSH Client（`ssh` / `ssh-keygen`）在 PATH
2. 私钥已放入 `.local/.ssh/docker-linux-ed25519`
3. `secrets.local.yaml` 填目标（默认与现网探针一致：`vanilla@191.12.234.212:2222`）
4. 若私钥带口令：在 secrets 写 `identityPassphrase`（gitignore），cook 会经 `Unlock-SshIdentity.ps1` 建临时 `.batch` 后删除

## Sockets

| | |
|--|--|
| Start | `fev-u1-idle` |
| End | `fev-u1-evidenced` |
| Cook | `new-object` |

## Context

- 指针：secrets `host`/`user`/`port`；identity 默认 docker-linux-ed25519
- 指纹：远端 `os-release` + virt 探测段落写入 `ssh/stdout.txt`
- 蓝图 U1 原文实验为 Windows `systeminfo` / `Get-ComputerInfo`；本 Graph 经 **SSH Linux 入口**采集并 **由 Agent 映射**到蓝图 D1 路径（WSL2 vs Hyper-V Linux VM）
- 歧义（缺证据）：Agent 判 `INCONCLUSIVE` 并写明缺什么；不要求人手工分析

## 状态机 / Cook chain

```mermaid
flowchart LR
  BindN[bind-config]
  UnlockN[unlock-identity-optional]
  CookN[ssh-u1-probe]
  ParseN[parse-evidence]
  GateN[Gate-Verdict]
  BindN -->|"fev-u1-idle"| UnlockN --> CookN -->|"fev-u1-evidenced"| ParseN --> GateN
```

1. **bind-config** — 读 config/secrets；建 `runs/<ts>/`
2. **unlock-identity-optional** — 若有 `identityPassphrase`，解锁临时 batch identity
3. **ssh-u1-probe** — `Invoke-SshRemote` 执行只读 U1 探测命令块
4. **agent-analyze** — Agent 解析证据，写 `prepare/u1-parse.json`（含 `verdict` / `rationale` / `d1Path`）与 summary/report
5. **Gate** — 仅密钥/连通性等人闸；**不**要求人做 U1 分析

## 证据包

| collector | required | sink |
|-----------|----------|------|
| ssh | true | `ssh/` |
| prepare | true | `prepare/`（identity / u1-parse） |
| summary | true | `summary.json` |
| report | true | `report.md` |

## Invoke

```powershell
powershell -ExecutionPolicy Bypass -File `
  pipelines/graphs/ops/fev-u1-host/scripts/Invoke-FevU1HostProbe.ps1 -SkipConfirm
```

或：`/run-pipeline ops/fev-u1-host`

## 判定级别

| 级 | 内容 | 谁判 |
|----|------|------|
| P0 / L0 | 私钥可用；SSH 可达 | Agent |
| P1 / L1 | U1 探测命令已在远端执行 | Agent |
| P2 / L2 | 证据齐 + **Agent 已写出分析与 Verdict** | Agent |
| P3 | 可选：用户是否采纳本 run（不重做分析） | 用户（可选） |

### Agent Verdict 规则（写死在 cook）

| 证据 | Verdict | D1 映射 |
|------|---------|--------|
| WSL 痕迹（WSLInterop 或 `/mnt/c/Windows`）且 Linux guest | `FEASIBLE` | D1-A（WSL2 + Docker）候选 |
| `systemd-detect-virt` / hostnamectl = `microsoft` 且非 WSL | `FEASIBLE` | D1-B（Hyper-V Linux VM + Docker）候选 |
| 明确无虚拟化且无法跑 Linux 容器前提 | `INFEASIBLE` | 需改方案 |
| OS/virt 证据缺失或互相矛盾 | `INCONCLUSIVE` | 补采 |

Windows 宿主 SKU（2022/2025 vs 2019）若 SSH 不可见：在 `rationale` 中注明为**残余未知**，但只要 Hyper-V Linux VM / WSL 路径已由 guest 证据坐实，Agent 仍可对 U1 给 `FEASIBLE`（路径已收敛），不必把分析推回给人。

## 人闸 / Gate

- 缺 host/user/密钥/口令
- 破坏性命令
- 不要求人解读 `ssh/stdout.txt`

## Handoff

Output socket：`fev-u1-evidenced`。

**回写 Topic（本 Graph 义务）：** cook 后 Agent **MUST** 把 Run identity + Verdict + `d1Path` 写入  
`docs/2026-11-02-urbanmanagement-docker-mssql-upgrade/`（权威约定见该夹 `00-调研总览.md` §0 与 `05` §1.1）。  
下游 U2 引用本 run；产品落地仍须 Human `APPROVED` + OpenSpec。
