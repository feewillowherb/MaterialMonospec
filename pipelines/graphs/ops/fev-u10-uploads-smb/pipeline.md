# fev-u10-uploads-smb（ops）

## 目的 / Goal

验证 Docker 虚拟机能否通过 SMB 使用 IIS 宿主机的 `C:\wwwroot\UrbanManagement\Uploads`，采集 **FEV U10** 证据。新栈若共用该目录，历史图片无需迁移，回滚也不丢新图。

蓝图：[`docs/2026-11-02-urbanmanagement-docker-mssql-upgrade/05-部署与切换回滚.md`](../../../../docs/2026-11-02-urbanmanagement-docker-mssql-upgrade/05-部署与切换回滚.md) §1 U10、§1.5 宿主机人工采集。上游：`ops/fev-u1-host`。

Goal 槽：`ops-fev-u10-uploads-smb` · Status: **active** · 路径：`pipelines/graphs/ops/fev-u10-uploads-smb/`

## 非目标

- 不在宿主机上建共享、建账号、改防火墙（Graph 只能 SSH 进虚拟机，宿主机侧由人执行）
- 不部署 UrbanManagement，不改 `repos/`
- 不处理现有 `wwwroot` / `Users` 共享的安全收紧

## 前置

1. `fev-u1-host` 已 `FEASIBLE`
2. `secrets.local.yaml`（同 `fev-u1-host`）
3. `setup` / `mount-test` 另需：宿主机专用共享与账号（人闸 `host-share-required`）；`setup` 需人提供 sudo 与共享密码；`-ProductionWrite` 需对生产 `Uploads` 写入的确认（人闸 `production-write-approval`）

## 模式

| 模式 | 远端动作 | 副作用 |
|------|----------|--------|
| `reach` | 从虚拟机对 Default Switch 网关与固定地址 `191.12.234.212` 做 TCP 445 连接，并对空闲对照端口 `47123` 做同样连接；检查 cifs 内核模块、`cifs-utils`、免密 sudo | 无 |
| `setup`（须 `-Apply`） | 写入并校验 `/etc/sudoers.d/90-<user>-ops`（免密 sudo）；安装 `cifs-utils`；写 `/etc/um-uploads.cred`（`600 root:root`） | 改虚拟机系统配置（幂等） |
| `mount-test` | 只读挂载 `//191.12.234.212/um-uploads` → 读一个历史 jpg → 20 个以内文件 stat 计时 → 卸载 | 无 |
| `mount-test -ProductionWrite` | 读写挂载，另在 `_probe/` 写入 200 KB、读回比对、删除，再删 `_probe/` | 在生产 `Uploads` 短暂写入一个文件（人闸 `production-write-approval`） |

**密码传递：** `setup` 从环境变量 `UM_VM_SUDO_PASSWORD` / `UM_SMB_PASSWORD` 取密码，只经 SSH 标准输入（`Invoke-SshRemote -StdinText`）送到远端；远端只在管道和 bash 内建命令中使用，不进 argv、日志或 `runs/`。cook 后 Agent 应在 `runs/` 中检索确认无泄漏。

**宿主机侧（人执行）：** 专用本地账号 `um-uploads` + 专用共享 `um-uploads → C:\wwwroot\UrbanManagement\Uploads`，仅该账号 Change 权限，移除 Everyone；不得复用 `wwwroot` 共享。

对照端口用于排除"所有端口都接受连接"的中间设备：对照端口也通时，445 通不能作为证据。

## Invoke

```powershell
$s = 'pipelines/graphs/ops/fev-u10-uploads-smb/scripts/Invoke-FevU10UploadsSmb.ps1'
powershell -ExecutionPolicy Bypass -File $s -Mode reach -SkipConfirm
# 人闸后；密码只放进当前进程环境变量，用完删除
powershell -ExecutionPolicy Bypass -File $s -Mode setup -Apply -SkipConfirm
powershell -ExecutionPolicy Bypass -File $s -Mode mount-test -SkipConfirm
# 人闸 production-write-approval 后
powershell -ExecutionPolicy Bypass -File $s -Mode mount-test -ProductionWrite -SkipConfirm
```

或：`/run-pipeline ops/fev-u10-uploads-smb`

## Agent Verdict 规则（reach，写死在 cook）

| 证据 | Verdict | 推荐地址 |
|------|---------|----------|
| 固定地址 445 通且对照端口不通 | `FEASIBLE` | `191.12.234.212` |
| 仅网关 445 通且对照端口不通 | `FEASIBLE`（附 N3：须先固定地址） | 网关 |
| 445 与对照端口都通 | `INCONCLUSIVE` | — |
| 两个地址 445 都不通 | `INFEASIBLE`（需改宿主防火墙/路由） | — |
| SSH 失败 | `INCONCLUSIVE`，result `blocked` | — |

reach 只覆盖 U10 的网络部分。`mount-test`：挂载失败 → `INFEASIBLE`；只读通过 → `INCONCLUSIVE`（写未测）；`-ProductionWrite` 下读写删都通过 → `FEASIBLE`。`setup` 不产出 Verdict。

## 判定级别

| 级 | 内容 | 谁判 |
|----|------|------|
| P0 | SSH 可达、私钥可用 | Agent |
| P1 | 远端脚本执行完成 | Agent |
| P2 | Agent 写出 `FEASIBLE` / `INFEASIBLE` | Agent |
| P3 | 是否采纳本 run | 用户 |

## Handoff

Output socket：`fev-u10-evidenced`。cook 后 Agent **MUST** 把 Run identity + Verdict 回写 `docs/2026-11-02-urbanmanagement-docker-mssql-upgrade/05-部署与切换回滚.md` §1 U10 行与 §1.x 回写节。产品落地仍须 Human `APPROVED` + OpenSpec。
