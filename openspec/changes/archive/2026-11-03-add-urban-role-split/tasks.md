## 0. 分支（Mode A）

- [x] 0.1 `repos/UrbanManagement` 自 `main` 切 `add-urban-role-split`；monospec 改 Graph 前切同名分支

## 1. 角色开关（UrbanManagement）

- [x] 1.1 `Core/Configuration/HostingOptions.cs`：`Roles`、`AutoMigrate`、`TrustForwardedHeaders`，`Includes(role)`、`RunsMigrations`、`IsMigratorOnly`；`HostingRoles` 常量；不注册 DI
- [x] 1.2 `UrbanManagementCoreModule`：后台任务注册增加 `Includes(Worker)` 判断，跳过时记日志
- [x] 1.3 `UrbanManagementAppModule`：tus 只在 Ingest；Hub、Blazor Hub、兜底页、`/ClientLogs` 只在 Console；迁移按 `RunsMigrations`，`IsMigratorOnly` 时失败抛出、成功后 `StopApplication`
- [x] 1.4 `SignalR:UseRedisBackplane` 时 `AddStackExchangeRedis`（前缀 `UM:signalr`）；`Directory.Packages.props` 加 `Microsoft.AspNetCore.SignalR.StackExchangeRedis` 10.0.0
- [x] 1.5 `Hosting:TrustForwardedHeaders` 时管道最前 `UseForwardedHeaders`
- [x] 1.6 `tests/UrbanManagement.Core.Tests`：`HostingOptions` 判定测试

## 2. 网关（UrbanManagement）

- [x] 2.1 新建 `src/UrbanManagement.Gateway`（Web SDK + `Yarp.ReverseProxy` 2.3.0），加入解决方案
- [x] 2.2 `appsettings.json`：路由表按 spec 顺序、`RequestHeaderOriginalHost`、`ActivityTimeout` 5 分钟、主动健康检查 `/health/ready`；Kestrel 不限请求体；`/health/gateway`
- [x] 2.3 本地冒烟：网关 + 全角色应用，`/health/gateway`、`/api/post` 与 `/` 路由到后端

## 3. 容器定义（UrbanManagement）

- [x] 3.1 `Dockerfile` 复制 `gateway/` 到 `/app/gateway`
- [x] 3.2 `compose.yaml` 改为 Phase 2 七个服务（design §8），沿用 Phase 1 卷名；`.env.example` 更新 MSSQL 上限默认 1280
- [x] 3.3 `dotnet build` 与 `dotnet test` 通过

## 4. 部署 Graph（monospec）

- [x] 4.1 `Invoke-DeployUrbanAcceptance.ps1`：发布网关并打入 bundle
- [x] 4.2 `remote-urban-deploy.sh`：`up -d --remove-orphans`；按角色检查（migrator 退出码、各角色 ready、网关路由、backplane 频道、后台任务日志、内存阈值 500 MB）
- [x] 4.3 `pipeline.md`、`acceptance.md`、`contract.yaml` 同步 Phase 2

## 5. 部署与验收

- [x] 5.1 合入前在虚拟机运行 Graph `deploy`，全部检查通过（run `2026-11-03T112909`，`pass`）
- [x] 5.2 外部 `5333` 经网关：`/health/ready`、`/` 200（`verify`）
- [x] 5.3 回写蓝图 `05`（Phase 2 段）、`03`、`06` K17
- [ ] 5.4 人工验收（P3，用户）：管理端登录与设备状态页；客户端数据连通性按用户决定不做
