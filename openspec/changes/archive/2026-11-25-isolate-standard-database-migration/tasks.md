## 1. OpenSpec 校验

- [x] 1.1 创建 OpenSpec 变更 `isolate-standard-database-migration` 并通过 `openspec validate isolate-standard-database-migration --strict`

## 2. 独立化 Standard 迁移程序

- [x] 2.1 新建 `repos/MaterialClient/src/MaterialClient.StandardMigrator/`（`MaterialClient.StandardMigrator.csproj`、`Program.cs`、`StandardDatabaseMigrator.cs`）并加入 `MaterialClient.sln`
- [x] 2.2 在 `MaterialClient.StandardMigrator` 中承接 legacy `__EFMigrationsHistory` 重命名、内核 + Standard `MigrateAsync()`、`PRAGMA integrity_check` 与 `WAL` 收口

## 3. 清理共享层与 Standard 客户端本体

- [x] 3.1 将 `EnsureWalJournalModeAsync` 内聚进 `SqliteSchemaBootstrap.cs`，删除 `KernelDatabaseMigrator.cs` 与 `SqliteMigrationHistoryMigrator.cs`
- [x] 3.2 更新 `MaterialClientModule.cs`（Standard 本体）使用 `SqliteSchemaBootstrap.EnsureInitializedAsync<StandardDbContext>` / `EnsureWalAsync`，移除 `MigrateStandardContextAsync` 与 `MigrateAsync()` 调用
- [x] 3.3 更新 `DeploymentPreflight.cs` 以兼容 `SqliteSchemaBootstrap` 全新建库的 Standard 数据库

## 4. 测试与全量构建验证

- [x] 4.1 更新 `SqliteWalMigrationTests.cs` 与 `SqliteSchemaBootstrapTests.cs` 覆盖 Standard 独立迁移工具与 4 宿主直建表 + WAL
- [x] 4.2 构建 `MaterialClient.sln` 并运行单元测试确认 0 错全通过，且所有桌面宿主与共享业务层 0 `MigrateAsync()` 残留
