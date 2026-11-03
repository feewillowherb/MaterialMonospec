## Why

D13（2026-11-03，用户）：单应用形态（Phase 1 `um-app`）不再单独验收和切换，直接进入蓝图 Phase 2 角色拆分，拆分后再验收。蓝图 [`03-目标架构与服务拆分.md`](../../../docs/2026-11-02-urbanmanagement-docker-mssql-upgrade/03-目标架构与服务拆分.md) 的 Phase 2 形态是一个 YARP 网关加按角色启动的同一镜像：客户端数据面（ingest）、管理端与实时面（console）、后台任务（worker）、一次性迁移（migrator）。当前代码只能以"全部角色"启动：迁移在每个实例启动时执行且失败被吞掉，后台任务只靠同步开关控制，SignalR 推送只到达本进程的连接，没有网关项目。

## What Changes

- **角色开关**：新增 `Hosting` 配置节（`Roles`、`AutoMigrate`、`TrustForwardedHeaders`）。`Roles` 为空表示全部角色，未配置时行为与现在一致。
  - `Console`：映射 `DeviceStatusHub`、Blazor Hub、兜底页面与 `/ClientLogs` 静态文件；
  - `Ingest`：映射 tus 端点；
  - `Worker`：只有包含该角色时才注册 `GovSyncBackgroundWorker` 与 `ClientStatusSnapshotBackgroundWorker`（仍受原有开关约束）；
  - `Migrator`：执行数据库迁移，失败时进程以非零退出码结束；仅含该角色时迁移完成后进程退出。
  - 控制器、ABP 自动 API、`/health/*` 在所有角色上映射，由网关决定可达性。
- **SignalR Redis backplane**：配置 `SignalR:UseRedisBackplane=true` 时，`IHubContext` 的推送经 Redis 到达 console 上的连接（ingest 上报后的设备状态推送、审批推送）。未配置时不变。
- **转发头**：`Hosting:TrustForwardedHeaders=true` 时启用 `UseForwardedHeaders`（`X-Forwarded-For`、`X-Forwarded-Proto`），角色容器只在 Docker 内部网络可达。
- **网关项目** `src/UrbanManagement.Gateway`：YARP，路由表按蓝图 `03` §5（路径大小写不敏感），保留原始 `Host`，对后端 `/health/ready` 主动探测，请求超时 5 分钟，不限制请求体大小；自身健康端点 `/health/gateway`。
- **容器定义**：同一镜像同时包含应用、网关（`/app/gateway`）与导入工具；`compose.yaml` 改为 Phase 2：`um-gateway`（发布 `5333`）、`um-ingest`、`um-console`、`um-worker`、`um-migrator`、`mssql`（`MSSQL_MEMORY_LIMIT_MB=1280`，D14）、`redis`。只有 `um-worker` 可能开启同步开关；验收默认全部关闭（D8）。
- **部署 Graph** `ops/deploy-urban-acceptance` 改为部署 Phase 2 栈并按角色验证（迁移容器退出码、各角色 ready、网关路由到 ingest / console、backplane 订阅、各角色后台任务注册情况、内存）。
- **决策**：D13（用户）、D14（Agent：不扩容，MSSQL 上限 1280 MB）。
- **非目标**：OpenTelemetry（D12）；Phase 3 深度拆分（Hub 多副本、ingest 多副本、`TusAttachmentResultStore` 外置）；非本角色路径的 404 防御中间件；客户端数据连通性验证（用户决定不做）；端口切换（用户执行）；MaterialClient 改动。

## Capabilities

### New Capabilities

- `urban-role-hosting`：同一应用按配置的角色启动，控制端点映射、后台任务注册、迁移执行、SignalR 跨进程推送与转发头。
- `urban-gateway`：YARP 网关按固定路由表把外部请求分到 ingest 与 console。

### Modified Capabilities

- `urban-container-deployment`：仓内容器定义由 Phase 1 单应用改为 Phase 2 角色拆分。

## Impact

- **仓**：`repos/UrbanManagement`，Mode A，分支 `add-urban-role-split` 自 `main`。
- **代码**：新增 `Core/Configuration/HostingOptions.cs`、`src/UrbanManagement.Gateway/`；修改 `UrbanManagementAppModule`、`UrbanManagementCoreModule`、`Directory.Packages.props`（`Yarp.ReverseProxy`、`Microsoft.AspNetCore.SignalR.StackExchangeRedis`）、解决方案文件、`deploy/docker/`；`tests/UrbanManagement.Core.Tests`。
- **主仓**：Graph `pipelines/graphs/ops/deploy-urban-acceptance/` 更新；蓝图 `00`、`03`、`05`、`06` 回写。
- **客户端接口**：不变。网关保留原始 `Host` 与路径，tus `Location` 不变。
- **现网 IIS**：不受影响。未配置 `Hosting` 时行为与现在一致。
