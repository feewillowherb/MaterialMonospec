## Context

- 目标环境：191 宿主（Windows 10 LTSC 1809）上的 Hyper-V Ubuntu 24.04 虚拟机 `docker-linux`，2 vCPU / 3.7 GiB（D7 暂不扩容），Docker 29.9.2 已装（U2 `FEASIBLE`）。宿主经 portproxy 把 `2222` 转到虚拟机 `22`。
- 附件：D10 修订后，新栈经 SMB 共用 IIS 的 `C:\wwwroot\UrbanManagement\Uploads`（共享 `um-uploads`，U10 `FEASIBLE`）。凭据已在虚拟机 `/etc/um-uploads.cred`。
- 验收：新实例在 `5333` 与 IIS 并行（D8），关闭对外同步；导入源为 `_tmp/UrbanManagement_test.upgraded.db`。
- 应用现状：tus 临时目录硬编码为 `{ContentRoot}/Uploads/_tus`；无健康检查端点；Data Protection 用默认密钥存储；Serilog 已输出 Console。

## Goals / Non-Goals

**Goals**

- 应用侧补齐容器运行所需的最小改动，未配置时与现网行为一致。
- 仓内有可复现的镜像与 compose 定义；虚拟机上一条 Graph 能完成部署、建库、导入、启动、验证，并可重复执行。

**Non-Goals**

- 宿主 Windows 侧配置（`5333` portproxy、防火墙）——Graph 无法进入宿主，由人执行，Graph 只验证外部可达。
- 端口切换、正式数据导入（D8，用户执行，另有 runbook）。
- `UseForwardedHeaders`、网关、角色拆分、Redis backplane（Phase 2）。

## Decisions

### 1. tus 临时目录：`StorageOptions:TusTempPath`

默认值 `Uploads/_tus`，相对路径按 ContentRoot 解析，绝对路径原样使用，解析逻辑放在 `StoragePathResolver.GetTusTempRootAbsolute()`，与附件根目录同一处。`TusAttachmentUploadConfigurationProvider` 改为注入 `IStoragePathResolver`。容器内设为 `/app/tus`（命名卷）。理由：D10 下 IIS 与新栈共用 `Uploads`，两边的 tus 过期清理会互删对方的临时文件（K21）；tus 分片频繁追加写，不应走 SMB。

### 2. 健康检查

- `/health/live`：不执行任何检查，只表示进程能响应。
- `/health/ready`：`ReadinessHealthCheck` 用 `ConnectionStrings:Default` 直接打开 `SqlConnection` 执行 `SELECT 1`，并确认附件根目录存在。不经 ABP UnitOfWork（避免手动 UoW），也不写入共享目录（避免每次探测都写生产 `Uploads`）。
- 用 `AddHealthChecks().AddCheck<ReadinessHealthCheck>(...)` 注册，类型由 `ActivatorUtilities` 创建，不额外注册 DI（minimal-di）。
- 端点映射在 `MapFallbackToPage` 之前；不在流量计量前缀内。

### 3. Data Protection

配置 `DataProtection:KeysPath` 时调用 `AddDataProtection().SetApplicationName("UrbanManagement").PersistKeysToFileSystem(...)`；未配置时不调用，IIS 现网行为不变。容器内为 `/app/keys`（命名卷）。

### 4. 镜像：只打包发布产物

`Dockerfile` 以 `mcr.microsoft.com/dotnet/aspnet:10.0` 为基础，`COPY` 本机 `dotnet publish -c Release` 的输出，不在镜像内还原 NuGet（虚拟机到 NuGet 的连通性未验证，`mcr` 已验证可达）。镜像内预建 `/app/Uploads`、`/app/tus`、`/app/keys`、`/app/Logs`、`/app/ClientLogs` 并归属 uid 1654，命名卷首次挂载时继承该属主；以 `USER 1654` 运行，监听 `8080`。导入工具 `UrbanManagement.DataImport` 一并发布到镜像 `/app/tools/import`，用同一镜像 `docker compose run` 执行，不需要第二个镜像。

### 5. compose（Phase 1）

| 服务 | 要点 |
|------|------|
| `mssql` | `2022-latest`，`MSSQL_PID=Express`（D3），`MSSQL_MEMORY_LIMIT_MB=1536`，`TZ=Asia/Shanghai`，数据卷 `um-mssql`，不发布端口，`sqlcmd` 健康检查 |
| `redis` | `redis:7-alpine`（经镜像加速），AOF，`maxmemory 128mb`，不发布端口 |
| `um-app` | 发布 `${UM_PUBLIC_PORT:-5333}:8080`；`ASPNETCORE_ENVIRONMENT=Production`；`TZ=Asia/Shanghai`；`/app/Uploads` 绑定 `${UM_UPLOADS_HOST_PATH}`；`appsettings.Production.json` 只读挂载；连接串、Redis、`TusTempPath`、`KeysPath`、同步开关由环境变量给出 |

配置优先级：`appsettings.json` < `appsettings.Production.json`（从 IIS 现网配置整理，去掉连接串 / Redis / 存储路径） < 环境变量。**不挂载** `appsettings.secret.json`：`Program.cs` 在环境变量之后才加载它，会反过来覆盖环境变量。

验收期（D8）环境变量：`BasePlatformSync__Enabled=false`、`BackgroundServices__Polling=false`（两者都为 false 时 `GovSyncBackgroundWorker` 不注册，见 `UrbanManagementCoreModule`），`StorageOptions__GovAddress=` 置空作为第二道保险。

### 6. 数据库账号

应用用业务登录 `um_app`（`UrbanManagement` 库 `db_owner`，启动迁移需要 DDL），不用 `sa`。Graph 在 `mssql` 健康后用 `sqlcmd` 幂等地：`CREATE DATABASE UrbanManagement COLLATE Chinese_PRC_CI_AS`（不存在时）、`CREATE LOGIN um_app`、映射用户并加入 `db_owner`。`sa` 与 `um_app` 密码由 Graph 在虚拟机上生成，写入 `/opt/urbanmanagement/.env`（`600 root`），不回传本机、不进证据。

### 7. 虚拟机上的 SMB 持久挂载

`/etc/fstab`：`//191.12.234.212/um-uploads /srv/um-uploads cifs credentials=/etc/um-uploads.cred,uid=1654,gid=1654,file_mode=0664,dir_mode=0775,noserverino,_netdev,nofail,x-systemd.automount 0 0`。`x-systemd.automount` 让开机时宿主 SMB 尚未就绪也不阻塞启动，首次访问时挂载；`um-app` 绑定 `/srv/um-uploads`，绑定传播设为 `rslave`：容器若先于 SMB 挂载启动，后来的挂载也会传播进容器，不会把照片写进虚拟机本地的空挂载点。

### 8. 部署 Graph 的执行顺序

本机：`dotnet publish` App 与 DataImport → 打包 tar。虚拟机：上传（scp）→ fstab 挂载 → 读取 IIS 现网配置（经 `wwwroot` 共享只读挂载；不可读时用本机配置兜底并标记 `config-source=local`）→ 生成 `appsettings.Production.json` 与 `.env` → `docker build` → `compose up mssql redis` → 建库与账号 → `compose run` 导入（`import`，目标为空库）→ `compose up um-app` → 虚拟机内 `curl` 健康检查与只读接口。重复执行时：库非空则跳过导入（导入工具本身拒绝非空库），`--reset` 模式才清库重导（人闸）。

## Risks / Trade-offs

- **内存（D7）**：mssql 约 0.6–1.6 GB、应用约 0.3–0.5 GB、redis < 0.15 GB，合计在 3.7 GiB 内但余量小。各服务设 `mem_limit`，Graph 记录部署后可用内存。
- **服务器排序规则**：U2 观测到 `MSSQL_COLLATION` 未生效（服务器级仍为 `SQL_Latin1_General_CP1_CI_AS`）。应用库由建库语句与 `SetDatabaseCollation` 迁移保证为 `Chinese_PRC_CI_AS`；`tempdb` 为 Latin1，EF 不使用跨库临时表，接受。
- **SMB 依赖（K20）**：共享不可用时上传失败、历史照片读不到。`/health/ready` 只检查目录存在，挂载掉线时 automount 会重新挂载；宿主重启演练归 U4。
- **验收期测试照片写入生产 `Uploads`**：D10 已接受。
- **镜像不含 NuGet 还原**：构建依赖本机 SDK；后续如需 CI 构建再加多阶段 Dockerfile。

## Migration Plan

1. 本 change 代码合入后，现网 IIS 不需要任何改动（新配置项都有与现网一致的默认值）。
2. 验收：Graph 部署到 `5333` → 人在宿主执行 portproxy 与防火墙 → Graph 验证外部可达 → 客户端提交测试数据。
3. 切换：按蓝图 `05` §3 runbook（用户执行）。

## Open Questions

- 宿主 `5333` 防火墙放行范围（仅局域网 / 全部）——由用户在执行宿主命令时决定，默认与现有 `5233` 规则一致。
