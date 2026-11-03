## Context

- Phase 1 栈已在虚拟机上运行（`add-urban-docker-deployment`，run `2026-11-03T103715`）：`um-app` + `mssql` + `redis`，`5333` 经宿主 portproxy 可达。D13 后该形态不再验收，Phase 2 栈替换它并沿用同一端口、库、卷与 SMB 挂载。
- 代码现状（`main` `75e069c`）：
  - `UrbanManagementAppModule.OnApplicationInitializationAsync` 每次启动都执行 `MigrateAsync`，异常被记录后继续启动。
  - `UrbanManagementCoreModule` 按 `BackgroundServices:Polling` / `BasePlatformSync:Enabled` 注册 `GovSyncBackgroundWorker`，按 `ClientStatusSnapshot:Enabled`（默认 `true`）注册快照任务。
  - 设备在线状态存于 ABP 分布式缓存（Redis），快照任务读缓存写库，可在独立进程运行。
  - `IHubContext<DeviceStatusHub>` 的使用者：`DeviceStatusService`（设备状态推送，上报路径也会调用）、`ServerApprovalSyncPushService`（审批后推送）、`ClientLogAppService`（日志拉取，依赖 Hub 进程内静态字典）。
- 资源（D14）：2 vCPU / 3.7 GiB，不扩容。

## Goals / Non-Goals

**Goals**

- 同一镜像按 `Hosting:Roles` 启动为 ingest / console / worker / migrator；未配置时与现在完全一致（IIS 与本地开发不受影响）。
- 网关按蓝图 `03` §5 路由；客户端无感（路径、Host、tus `Location` 不变）。
- 部署 Graph 能重复部署 Phase 2 栈并按角色给出证据。

**Non-Goals**

- Phase 3（Hub / ingest 多副本、日志拉取改内部 API、`TusAttachmentResultStore` 外置）。
- 非本角色路径的 404 中间件（角色容器不对外发布端口）。
- OpenTelemetry（D12）。

## Decisions

### 1. `HostingOptions`（类型自带判定方法）

```csharp
public class HostingOptions
{
    public const string SectionName = "Hosting";
    public string[] Roles { get; set; } = [];
    public bool AutoMigrate { get; set; } = true;
    public bool TrustForwardedHeaders { get; set; }

    public bool Includes(string role);      // Roles 为空 => true；大小写不敏感
    public bool RunsMigrations { get; }     // AutoMigrate || Includes(Migrator)
    public bool IsMigratorOnly { get; }     // Roles 只有 Migrator
}
public static class HostingRoles { Ingest, Console, Worker, Migrator }
```

- 不注册 DI；模块内用 `configuration.GetSection(...).Get<HostingOptions>()` 读取（minimal-di、type-owned-methods）。
- `appsettings.json` 不写 `Roles` 默认数组（数组按下标合并，蓝图 `03` §4）。

### 2. 端点映射

| 端点 | 条件 |
|------|------|
| `MapControllers`（含 ABP 自动 API）、`/health/live`、`/health/ready` | 总是 |
| `MapTus` | `Includes(Ingest)` |
| `MapHub<DeviceStatusHub>`、`MapBlazorHub`、`MapFallbackToPage`、`/ClientLogs` 静态文件 | `Includes(Console)` |
| `UseStaticFiles()`（wwwroot） | 总是（体积小，Blazor 资源在 console 使用） |

### 3. 迁移

- `RunsMigrations` 为 false 时跳过迁移。
- `IsMigratorOnly` 时迁移异常不再吞掉而是抛出，进程以非零退出码结束；成功后调用 `IHostApplicationLifetime.StopApplication()`，进程以 0 退出。compose 中其他角色 `depends_on: um-migrator: service_completed_successfully`。
- 其他角色在 compose 中设 `Hosting__AutoMigrate=false`；全部角色（未配置）保持原行为（自动迁移、失败只记录）。

### 4. 后台任务

`UrbanManagementCoreModule` 在原有开关之外再判断 `Includes(Worker)`：不含 Worker 的角色即使开关为 true 也不注册，日志写明原因。避免切换时误把同步开关配到 ingest / console 上导致重复推送政府平台。

### 5. SignalR Redis backplane

- `SignalR:UseRedisBackplane=true` 且 `Redis:Configuration` 非空时 `AddSignalR().AddStackExchangeRedis(configuration, o => o.Configuration.ChannelPrefix = RedisChannel.Literal("UM:signalr"))`。
- 作用：ingest / worker 上 `IHubContext` 对组的推送经 Redis 发布，console 订阅后送达其连接。Hub 静态字典（日志拉取、连接映射）仍只在 console，日志拉取请求路由到 console（网关路由 1、12、13），不受影响。
- 包：`Microsoft.AspNetCore.SignalR.StackExchangeRedis` 10.0.0（与 `Microsoft.AspNetCore.SignalR.Client` 同版本线）。

### 6. 转发头

`TrustForwardedHeaders=true` 时在管道最前 `UseForwardedHeaders`：`XForwardedFor | XForwardedProto`，清空 `KnownNetworks` / `KnownProxies`（角色容器不发布端口，只有网关能访问）。`Host` 由网关原样保留，不处理 `X-Forwarded-Host`。

### 7. 网关项目 `src/UrbanManagement.Gateway`

- `Microsoft.NET.Sdk.Web` + `Yarp.ReverseProxy` 2.3.0，无 ABP。路由与集群在 `appsettings.json`，后端地址用环境变量覆盖（`ReverseProxy__Clusters__ingest__Destinations__d1__Address`）。
- 路由按蓝图 `03` §5，用 `Order` 固定顺序；YARP 路径匹配大小写不敏感，兼容 `/Api/Post`。
- 变换：`RequestHeaderOriginalHost: true`；YARP 默认追加 `X-Forwarded-*`。
- 集群：`HttpRequest.ActivityTimeout = 00:05:00`；主动健康检查 `/health/ready`，间隔 15 s。
- Kestrel `MaxRequestBodySize = null`（由后端限制）。
- 自身健康端点 `GET /health/gateway`（字面路由优先于代理的兜底路由）。外部 `/health/ready` 经兜底路由到 console，作为端到端探测。
- Serilog 不引入；用默认控制台日志。

### 8. 镜像与 compose

- 一个镜像：`/app`（应用）、`/app/gateway`（网关）、`/app/tools/import`（导入工具）。网关服务 `working_dir: /app/gateway`、`entrypoint: dotnet UrbanManagement.Gateway.dll`。一次构建，标签一致。
- 服务与卷：

| 服务 | 角色 / 关键环境 | 卷 | `mem_limit` |
|------|-----------------|----|-------------|
| `um-gateway` | 发布 `${UM_PUBLIC_PORT:-5333}:8080` | — | 160m |
| `um-migrator` | `Migrator`，`restart: "no"` | — | 384m |
| `um-ingest` | `Ingest` | Uploads（SMB，rslave）、`um-tus`、`um-keys`、`um-logs-ingest` | 512m |
| `um-console` | `Console` | Uploads、`um-keys`、`um-logs`、`um-clientlogs` | 640m |
| `um-worker` | `Worker`，同步开关来自 `.env`（默认 false） | Uploads、`um-keys`、`um-logs-worker` | 384m |
| `mssql` | `MSSQL_MEMORY_LIMIT_MB=${UM_MSSQL_MEMORY_LIMIT_MB:-1280}` | `um-mssql` | 1792m |
| `redis` | 同 Phase 1 | `um-redis` | 192m |

- 公共环境：`Hosting__AutoMigrate=false`、`Hosting__TrustForwardedHeaders=true`、`SignalR__UseRedisBackplane=true`、非 worker 的 `BasePlatformSync__Enabled` / `BackgroundServices__Polling` 固定为 false。
- 沿用 Phase 1 的卷名（`um-mssql`、`um-redis`、`um-tus`、`um-keys`、`um-logs`、`um-clientlogs`），库与密钥不丢；`docker compose up --remove-orphans` 移除旧 `um-app`。

### 9. Graph 调整

- 本机多发布网关；远端流程不变（建库与导入仍在应用启动前，导入工具自带迁移），最后 `up -d --remove-orphans`。
- 角色容器无 `curl`：用 `bash` 的 `/dev/tcp` 在容器内请求 `127.0.0.1:8080/health/ready`。
- 证据：`um-migrator` 退出码；各角色 ready；网关 `/health/gateway`、`/health/ready`、`/`（console）、`OPTIONS /api/urban-attachment/tus/`（只有 ingest 映射 tus，返回 204 与 `Tus-Version` 即证明路由到 ingest）、`POST /hubs/devicestatus/negotiate`（console）；Redis `PUBSUB CHANNELS UM:signalr*` 非空；各角色后台任务注册日志；内存（D14 阈值 500 MB）。

## Risks / Trade-offs

- **内存（D14）**：拆分后多两个 .NET 进程。Graph 记录可用内存，低于 500 MB 回到扩容决策。
- **Blazor 电路与 backplane**：backplane 对所有 Hub 生效（含 Blazor 的组件 Hub），console 单副本，影响仅为 Redis 少量订阅。
- **迁移失败可见性**：仅 migrator 抛出；全部角色（IIS）保持"失败只记录"的旧行为，避免现网启动方式改变。
- **日志拉取**：依赖 console 单进程（Hub 静态字典 + `TaskCompletionSource`），Phase 3 前 console 必须单副本。

## Migration Plan

1. 合入后 IIS 现网不受影响（未配置 `Hosting`、`SignalR:UseRedisBackplane`）。
2. Graph `deploy` 重跑：构建新镜像 → 库已有数据跳过导入 → `up -d --remove-orphans`：`um-migrator` 完成后三个角色与网关启动，旧 `um-app` 移除；`5333` 由网关接管，宿主 portproxy 不变。
3. 回滚：`.env` 的 `UM_TAG` 指回上一个镜像并换回 Phase 1 `compose.yaml`（`releases/<run>/` 中保留）。

## Open Questions

（无）
