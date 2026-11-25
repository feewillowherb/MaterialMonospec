## Why

上一轮变更将 Urban、Recycle、SolidWaste 三个宿主切到了 `SqliteSchemaBootstrap`，但 Standard 客户端本体（`MaterialClientModule.cs`）与共享层（`MaterialClient.Common.EntityFrameworkCore`）中仍然残留 `KernelDatabaseMigrator`、`SqliteMigrationHistoryMigrator.RenameLegacyHistoryTableIfNeededAsync` 与 `standardDb.Database.MigrateAsync()`。为彻底实现“业务代码和所有客户端本体 0 迁移/升级代码”，需要将 Standard 的数据库迁移功能独立到专门的控制台程序 `MaterialClient.StandardMigrator` 中。

## What Changes

- 新增独立控制台项目 `repos/MaterialClient/src/MaterialClient.StandardMigrator/` 并加入 `MaterialClient.sln`，专门负责 Standard 老库的离线迁移（`RenameLegacyHistoryTableIfNeededAsync` + 内核 `MigrateAsync` + `StandardDbContext.MigrateAsync` + `PRAGMA integrity_check` + `WAL` 收口）。
- 从 `MaterialClient.Common.EntityFrameworkCore` 移除 `KernelDatabaseMigrator.cs` 和 `RenameLegacyHistoryTableIfNeededAsync`，共享层仅保留 `SqliteSchemaBootstrap.cs`（空库直接按模型建表 + `EnsureWalJournalModeAsync`）。
- 更新 `MaterialClientModule.cs`（Standard 宿主）：与 Urban / Recycle / SolidWaste 保持一致，全新空库使用 `SqliteSchemaBootstrap.EnsureInitializedAsync<StandardDbContext>`，已有库仅调用 `SqliteSchemaBootstrap.EnsureWalAsync`，客户端本体不再调用任何 `MigrateAsync()`。
- 更新 `DeploymentPreflight.cs`（当 Standard 库由 `SqliteSchemaBootstrap` 全新创建、无 `__EFMigrationsHistory_Kernel` 时按内核必选表与产品身份放行；若存在迁移历史表则继续校验基线与未知迁移 ID）。
- 更新单元测试，覆盖 `MaterialClient.StandardMigrator` 迁移路径与 4 个宿主均无迁移代码。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `product-dbcontext-isolation`：所有 4 个桌面客户端宿主（含 Standard）均不再在启动时执行 EF `MigrateAsync()` 或 legacy history table 重命名；Standard 存量库迁移完全隔离至独立控制台程序 `MaterialClient.StandardMigrator`。

## Impact

- 影响子仓库：`repos/MaterialClient`（`MaterialClient.sln`、新增 `src/MaterialClient.StandardMigrator/`、清理 `MaterialClient.Common.EntityFrameworkCore`、更新 `MaterialClient/MaterialClientModule.cs`、`MaterialClient.Common/Hosting/DeploymentPreflight.cs` 及 `MaterialClient.Common.Tests`）。
- 4 个桌面宿主及共享业务层实现 **0 迁移/升级代码残留**。
