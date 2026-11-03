# deploy-urban-acceptance（ops）

## 目的 / Goal

把 UrbanManagement Phase 1（`um-app` + `mssql` + `redis`）部署到 Docker 虚拟机的 `5333`，与 IIS（`5233`）并行验收（D8）。附件经 SMB 共用 IIS 的 `Uploads`（D10），导入测试库，关闭对外同步。

蓝图：[`docs/2026-11-02-urbanmanagement-docker-mssql-upgrade/05-部署与切换回滚.md`](../../../../docs/2026-11-02-urbanmanagement-docker-mssql-upgrade/05-部署与切换回滚.md) §2。OpenSpec：`openspec/changes/add-urban-docker-deployment`（design 决策 4–8）。上游：`ops/fev-u2-docker`、`ops/fev-u10-uploads-smb`。

Goal 槽：`ops-deploy-urban-acceptance` · Status: **active** · 路径：`pipelines/graphs/ops/deploy-urban-acceptance/`

## 非目标

- 不改宿主机：`5333` portproxy、防火墙、IIS 由人执行（人闸 `host-portproxy-required`）
- 不做端口切换和正式数据导入（runbook，用户执行）
- 不开启 `BasePlatformSync` / `Polling`

## 模式

| 模式 | 动作 | 副作用 |
|------|------|--------|
| `deploy`（须 `-Apply`） | 本机 `dotnet publish` App 与 DataImport → 打包 → scp → 虚拟机：解包到 `/opt/urbanmanagement/releases/<run>`、写 fstab 并启用 `/srv/um-uploads` automount、只读挂载 `wwwroot` 共享取 IIS `appsettings*.json` 合并为 `appsettings.Production.json`（去掉连接串 / Kestrel / 存储路径；读不到时用本机 `appsettings.secret.json` 兜底，`CONFIG_SOURCE=local`）、首次生成 `.env`、`docker build`、起 `mssql`/`redis`、建库与 `um_app` 登录、空库时导入、起 `um-app`、检查 | 改虚拟机（幂等）；验收期测试照片写入生产 `Uploads`（D10 已接受） |
| `deploy -ResetDatabase` | 同上，但先删除 `UrbanManagement` 库再导入 | 丢弃虚拟机库内数据（人闸 `reset-database-approval`） |
| `verify` | 只做检查（健康、容器内挂载 / tus / 密钥 / 时区、日志、内存）+ 本机访问 `http://191.12.234.212:5333/health/ready` | 无 |

**密钥：** `sa` 与 `um_app` 密码在虚拟机上生成，只存在 `/opt/urbanmanagement/.env`（`600 root`）与容器环境中；导入工具的目标连接串取自容器自身的 `ConnectionStrings__Default`。本机 `appsettings.secret.json` 只经 SSH 标准输入送达，且只在 IIS 配置读不到时落盘（`600 root`）。cook 后 Agent 应检索 `runs/` 确认无泄漏。

**重复执行：** `.env` 已存在则保留；库内已有数据则跳过导入（`IMPORT=skipped-nonempty`）；每次 run 生成新镜像标签 `urbanmanagement-app:<run>` 并更新 `latest`。

## 宿主机侧（人执行，管理员 PowerShell）

验收入口 `5333`，与现有 `2222 → 22` 同样经 portproxy 转到虚拟机（虚拟机地址 `172.17.56.158` 受 N3 影响，宿主重启后需核对）：

```powershell
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=5333 connectaddress=172.17.56.158 connectport=5333
New-NetFirewallRule -DisplayName "UrbanManagement acceptance 5333" -Direction Inbound -Protocol TCP -LocalPort 5333 -Action Allow
netsh interface portproxy show v4tov4
```

放行范围默认与现有 `5233` 规则一致；需要限制来源时给 `New-NetFirewallRule` 加 `-RemoteAddress`。撤销：`netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=5333` 与 `Remove-NetFirewallRule -DisplayName "UrbanManagement acceptance 5333"`。执行后跑 `verify`。

## Invoke

```powershell
$s = 'pipelines/graphs/ops/deploy-urban-acceptance/scripts/Invoke-DeployUrbanAcceptance.ps1'
powershell -ExecutionPolicy Bypass -File $s -Mode deploy -Apply -SkipConfirm
powershell -ExecutionPolicy Bypass -File $s -Mode verify -SkipConfirm
```

或：`/run-pipeline ops/deploy-urban-acceptance`

## 结果规则（写死在 cook）

| 证据 | result |
|------|--------|
| 远端完成，ready/live 200，容器内 `/app/Uploads` 为 SMB，tus 可写，镜像内无 `appsettings.secret.json`，导入完成或跳过，外部 `5333` 200 | `pass` |
| 同上但外部 `5333` 不通 | `blocked`（`host-portproxy-required`） |
| SSH 失败 | `blocked` |
| 其他 | `fail`（`FAILED_AT` 指出步骤） |

## 判定级别

| 级 | 内容 | 谁判 |
|----|------|------|
| P0 | SSH 可达、私钥可用 | Agent |
| P1 | 远端脚本 exit 0 | Agent |
| P2 | 栈在虚拟机内健康（不含外部可达） | Agent |
| P3 | 是否采纳本 run（含客户端提交测试） | 用户 |

## Handoff

Output socket：`urban-acceptance-deployed`。cook 后 Agent **MUST** 把 Run identity 与结果回写蓝图 `05` §2，并更新 `add-urban-docker-deployment` 的 `tasks.md`。产品通过仍须 Human `APPROVED`。
