# deploy-urban-acceptance（ops）

## 目的 / Goal

把 UrbanManagement 微服务工程拆分后的栈（每个服务一个工程、一个镜像；网关 `um-gateway` + 角色 `um-ingest` ×2（`um-ingest`、`um-ingest-2`）/ `um-attachment` / `um-realtime` / `um-admin` / `um-worker` + 一次性 `um-migrator` + `mssql` + `redis`）部署到 Docker 虚拟机的 `5333`，与 IIS（`5233`）并行验收（D8）。Phase 1 单应用形态不再验收（D13）；重跑 `deploy` 会以 `--remove-orphans` 移除旧 `um-app`。附件经 SMB 共用 IIS 的 `Uploads`（D10），导入测试库，关闭对外同步。

蓝图：[`docs/2026-11-02-urbanmanagement-docker-mssql-upgrade/05-部署与切换回滚.md`](../../../../docs/2026-11-02-urbanmanagement-docker-mssql-upgrade/05-部署与切换回滚.md) §2。OpenSpec：`add-urban-docker-deployment`（基础设施，已归档）、`add-urban-role-split`（角色拆分，design §8–§9）、`refactor-urban-microservice-hosts`（工程拆分）。上游：`ops/fev-u2-docker`、`ops/fev-u10-uploads-smb`。

Goal 槽：`ops-deploy-urban-acceptance` · Status: **active** · 路径：`pipelines/graphs/ops/deploy-urban-acceptance/`

## 非目标

- 不改宿主机：`5333` portproxy、防火墙、IIS 由人执行（人闸 `host-portproxy-required`）
- 不做端口切换和正式数据导入（runbook，用户执行）
- 不开启 `BasePlatformSync` / `Polling`

## 模式

| 模式 | 动作 | 副作用 |
|------|------|--------|
| `deploy`（须 `-Apply`） | 本机逐个 `dotnet publish` 七个服务工程（Gateway、Ingest、Attachment、Realtime、Admin、Worker、Migrator）与 DataImport → 打包 → scp → 虚拟机：解包到 `/opt/urbanmanagement/releases/<run>`、写 fstab 并启用 `/srv/um-uploads` automount、只读挂载 `wwwroot` 共享取 IIS `appsettings*.json` 合并为 `appsettings.Production.json`（去掉连接串 / Kestrel / 存储路径；读不到时用本机 `src/UrbanManagement.Hosting/appsettings.secret.json` 兜底，`CONFIG_SOURCE=local`）、首次生成 `.env`（每次把 `UM_MSSQL_MEMORY_LIMIT_MB` 设为 `mssqlMemoryLimitMb`，D14）、按服务 `docker build`（`--build-arg SERVICE=<名>`，Worker 用 `--target worker` 带导入工具）、起 `mssql`/`redis`、建库与 `um_app` 登录、空库时导入（经 `um-worker` 服务定义运行导入工具）、`up -d --remove-orphans`（`um-migrator` 成功退出后才启动三个角色，网关最后）、检查 | 改虚拟机（幂等）；验收期测试照片写入生产 `Uploads`（D10 已接受） |
| `deploy -ResetDatabase` | 同上，但先删除 `UrbanManagement` 库再导入 | 丢弃虚拟机库内数据（人闸 `reset-database-approval`） |
| `verify` | 只做检查（网关健康与路由、各角色 ready、迁移容器退出码、backplane、各角色后台任务注册、挂载 / tus / 密钥 / 时区、日志、内存）+ 本机访问 `http://191.12.234.212:5333/health/ready` | 无 |

**密钥：** `sa` 与 `um_app` 密码在虚拟机上生成，只存在 `/opt/urbanmanagement/.env`（`600 root`）与容器环境中；导入工具的目标连接串取自容器自身的 `ConnectionStrings__Default`。本机 `appsettings.secret.json` 只经 SSH 标准输入送达，且只在 IIS 配置读不到时落盘（`600 root`）。cook 后 Agent 应检索 `runs/` 确认无泄漏。

**重复执行：** `.env` 已存在则保留；库内已有数据则跳过导入（`IMPORT=skipped-nonempty`）；每次 run 为七个镜像 `urbanmanagement-<service>` 生成同一标签 `<run>` 并更新 `latest`。

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
| 远端完成；网关 ready/live/`/health/gateway` 200；网关 `OPTIONS /api/urban-attachment/tus/` 204 且带 `Tus-Version`（attachment 容器内同样 204，ingest 不是 204：只有 attachment 映射 tus）；网关 `GET /hubs/devicestatus` 400、negotiate 200，realtime 容器内 400、其余角色不是 400（只有 realtime 映射 Hub；admin 的 Blazor 回退页会回 200）；admin 容器 `GET /` 200/302，realtime 容器 `GET /` 404（`_Host` 只在 Admin 工程里）；网关 `/internal/client-log/online-clients` 404，admin 容器访问 `um-realtime` 同路径 200；网关 `/api/app/client-log/online-clients` 200（路由到 realtime）；六个角色容器内 `/health/ready` 200；`um-migrator` 退出码 0 且日志有迁移完成；旧 `um-app` 不存在；非 worker 容器未注册快照任务，worker 注册快照任务，任何容器未注册 GovSync；构建出 7 个服务镜像，每个容器日志的 `UrbanManagement service:` 与 `/app` 下唯一的服务程序集都是本服务，`tusdotnet.dll` 只在 attachment、`Volo.Abp.AspNetCore.Components.Server.dll` 只在 admin、导入工具只在 worker；Redis 有 `UM:signalr*` 频道；六个角色 `/app/Uploads` 为 SMB；attachment 的 tus 可写；镜像内无 `appsettings.secret.json`；导入完成或跳过；虚拟机可用内存 ≥ `memMinAvailableMb`；外部 `5333` 200 | `pass` |
| 栈健康但虚拟机可用内存低于 `memMinAvailableMb` | `blocked`（`vm-memory-below-threshold`，扩容由人决策，D14） |
| 同上但外部 `5333` 不通 | `blocked`（`host-portproxy-required`） |
| SSH 失败 | `blocked` |
| 其他 | `fail`（`FAILED_AT` 指出步骤） |

## 判定级别

| 级 | 内容 | 谁判 |
|----|------|------|
| P0 | SSH 可达、私钥可用 | Agent |
| P1 | 远端脚本 exit 0 | Agent |
| P2 | 栈在虚拟机内健康（不含外部可达） | Agent |
| P3 | 是否采纳本 run（管理端页面与设备状态；客户端数据连通性按用户决定不验） | 用户 |

## Handoff

Output socket：`urban-acceptance-deployed`。cook 后 Agent **MUST** 把 Run identity 与结果回写蓝图 `05`（Phase 2 段），并更新当前 change（`add-urban-role-split`）的 `tasks.md`。产品通过仍须 Human `APPROVED`。
