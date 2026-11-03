## Why

`update-urban-mssql-provider` 让 UrbanManagement 能在 SQL Server 上运行，但服务仍然只能以 IIS 方式部署。蓝图 Phase 1（[`docs/2026-11-02-urbanmanagement-docker-mssql-upgrade/`](../../../docs/2026-11-02-urbanmanagement-docker-mssql-upgrade/00-调研总览.md)）要求新栈在 191 宿主的 Hyper-V Ubuntu 虚拟机里以 Docker 运行，先在 `5333` 与 IIS（`5233`）并行验收，再由用户执行端口切换（D8）。要做到这一点，应用需要几处容器化必需的改动，仓内需要可复现的镜像与 compose 定义，部署与导入需要一条可重复执行的 Graph。

## What Changes

- **tus 临时目录可配置**：新增 `StorageOptions:TusTempPath`（默认 `Uploads/_tus`，与现网行为一致）。容器内放本地卷，不再与 IIS 共用 `Uploads/_tus`（D10 共用 `Uploads` 后的必需项，风险 K21）。
- **健康检查**：`/health/live`（进程存活）与 `/health/ready`（数据库可连接、附件根目录存在），映射在 Blazor 兜底路由之前。
- **Data Protection 密钥持久化**：配置 `DataProtection:KeysPath` 时把密钥环写入该目录（容器卷），容器重建后管理端登录态不失效（K9）。未配置时行为不变。
- **容器定义**（UrbanManagement 仓 `deploy/docker/`）：
  - `Dockerfile`：基于 `mcr.microsoft.com/dotnet/aspnet:10.0`，只打包 `dotnet publish` 产物，非 root 运行（uid 1654）；
  - `compose.yaml`：`um-app` + `mssql`（2022 Express，`MSSQL_MEMORY_LIMIT_MB=1536`）+ `redis`；`um-app` 直接发布 `5333`（D11 无网关），`/app/Uploads` 绑定虚拟机上的 SMB 挂载点（D10），验收期关闭对外同步（D8）；
  - `.env.example`：只列变量名，真实值只在虚拟机上。
- **部署 Graph** `pipelines/graphs/ops/deploy-urban-acceptance/`：本机发布 → 传到虚拟机 → 配置 SMB 持久挂载 → 构建镜像 → 启动 `mssql`/`redis` → 建库与业务账号 → 用 `UrbanManagement.DataImport` 导入测试源 → 启动 `um-app` → 在虚拟机上验证健康检查与接口。
- **决策**：D3 = Phase 1 用 **MSSQL Express**（测试库 6 MB；现网库体积在切换前由导入普查确认，超过 8 GB 时重新决策）；D11 = Phase 1 不部署网关。
- **非目标**：宿主 `5333` 端口转发与防火墙（Windows 宿主操作，由人执行，Graph 只验证）；端口切换本身（D8，用户执行）；`UseForwardedHeaders`（验收期为四层转发，Host 头保留，不需要）；角色拆分与网关（Phase 2）；MaterialClient 任何改动。

## Capabilities

### New Capabilities

- `urban-container-deployment`：UrbanManagement 以容器方式运行所需的应用侧能力（可配置 tus 临时目录、健康检查端点、Data Protection 密钥持久化）以及仓内容器定义。

### Modified Capabilities

（无）

## Impact

- **仓**：`repos/UrbanManagement`。分支 `add-urban-docker-deployment` 自 `update-urban-mssql-provider` 切出（依赖其 SQL Server Provider 与导入工具，后者尚未合入 `main`；合入时按顺序 squash）。
- **代码**：`StorageOptions`、`StoragePathResolver`、`TusAttachmentUploadConfigurationProvider`、`UrbanManagementAppModule`；新增 `Health/ReadinessHealthCheck.cs`、`deploy/docker/`；`tests/UrbanManagement.Core.Tests`。
- **主仓**：新增 Graph `pipelines/graphs/ops/deploy-urban-acceptance/`；蓝图 `05` 回写部署 Run。
- **客户端接口**：不变。新增的 `/health/*` 为只读端点，不与现有路由冲突。
- **现网 IIS**：不受影响。未配置新选项时默认值与现网一致。
