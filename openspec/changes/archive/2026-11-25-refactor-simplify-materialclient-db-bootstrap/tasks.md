## 1. OpenSpec 与分支准备

- [x] 1.1 创建 OpenSpec 变更 `refactor-simplify-materialclient-db-bootstrap` 并通过 `openspec validate refactor-simplify-materialclient-db-bootstrap --strict`
- [x] 1.2 在 `repos/MaterialClient` 从 `main` 切出同名分支 `refactor-simplify-materialclient-db-bootstrap`（Mode A）

## 2. 移除退役迁移/升级项目

- [x] 2.1 从 `repos/MaterialClient/MaterialClient.sln` 移除 `MaterialClient.Toolkit` 与 `MaterialClient.DatabaseUpgrade`，并删除对应源码目录
- [x] 2.2 更新 `DeploymentPreflight.cs`、`HostBootstrap.cs` 及 `HostIsolationTests.cs`，移除 `MaterialClient.DatabaseUpgrade.exe` 提示与固废历史迁移表强制依赖，保留产品身份与固废扩展表校验

## 3. 简化非 Standard 宿主数据库启动引导

- [x] 3.1 新增静态 `SqliteSchemaBootstrap.EnsureInitializedAsync<TProductDbContext>`（空库按当前模型建内核表 + 产品表 + WAL；已有库仅确保 WAL）
- [x] 3.2 更新 `MaterialClientUrbanModule`、`MaterialClientRecycleModule`、`MaterialClientSolidWasteModule` 使用 `SqliteSchemaBootstrap.EnsureInitializedAsync`；保持 `MaterialClient`（Standard）迁移路径不变

## 4. 单元测试与全宿主构建验证

- [x] 4.1 补充 `SqliteSchemaBootstrap` 单元测试（Urban / Recycle / SolidWaste 全新建库 + WAL + 幂等二次启动）并更新受影响的既有测试
- [x] 4.2 运行 `MaterialClient.Common.Tests` 相关测试并验证 `MaterialClient.sln` / 4 个桌面宿主编译通过（`MaterialClient.sln` 0 Error；21/21 测试通过）
