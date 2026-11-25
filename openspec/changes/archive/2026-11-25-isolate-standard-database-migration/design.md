## Context

当前 `repos/MaterialClient/src/` 中仅剩 3 处迁移/升级代码：
1. `src/MaterialClient/MaterialClientModule.cs`（Standard 宿主启动调用 `KernelDatabaseMigrator.MigrateAsync` + `standardDb.Database.MigrateAsync()`）
2. `src/MaterialClient.Common.EntityFrameworkCore/KernelDatabaseMigrator.cs`
3. `src/MaterialClient.Common.EntityFrameworkCore/SqliteMigrationHistoryMigrator.cs` 中的 `RenameLegacyHistoryTableIfNeededAsync`

## Decisions

1. **新增独立程序 `MaterialClient.StandardMigrator`**：
   - 控制台程序，引用 `MaterialClient.Common.EntityFrameworkCore` 与 `MaterialClient.Common.Standard`。
   - 提供 `StandardDatabaseMigrator.MigrateFileAsync(string databasePath, CancellationToken cancellationToken)`：
     - 校验目标文件存在，先通过 `SqliteConnection.BackupDatabase` 备份至 `.bak-<timestamp>`（或按 CLI 参数指定路径）；
     - 执行 legacy `__EFMigrationsHistory` → `__EFMigrationsHistory_Kernel` 重命名（仅当文件已存在且有 legacy 表时）；
     - 按顺序执行 `MaterialClientDbContext.Database.MigrateAsync()` 与 `StandardDbContext.Database.MigrateAsync()`；
     - 执行 `PRAGMA integrity_check;` 校验与 `PRAGMA journal_mode = WAL;` 收口。
2. **清理共享层与 Standard 客户端本体**：
   - 删除 `MaterialClient.Common.EntityFrameworkCore/KernelDatabaseMigrator.cs` 与 `SqliteMigrationHistoryMigrator.cs`，将 `EnsureWalJournalModeAsync` 直接内聚到 `SqliteSchemaBootstrap.cs` 中。
   - `MaterialClientModule.cs` 改为：
     - `!HostStartupGate.ExistingDeployment` → `await SqliteSchemaBootstrap.EnsureInitializedAsync<StandardDbContext>(context.ServiceProvider);`
     - `HostStartupGate.ExistingDeployment` → `await SqliteSchemaBootstrap.EnsureWalAsync(context.ServiceProvider);`
   - 这样 4 个桌面客户端（Standard / SolidWaste / Urban / Recycle）与共享业务层全部零 `MigrateAsync()` 调用、零 legacy 表重命名代码。
3. **兼容 `DeploymentPreflight`**：
   - Standard 已有库若包含 `__EFMigrationsHistory_Kernel`，继续按 `SupportedSchemaManifest` 校验基线与未知迁移 ID；若为 `SqliteSchemaBootstrap` 全新建库（无迁移历史表），则按内核必选表 + `SavedMode == WeighingMode.Standard` 放行。

## Risks / Trade-offs

- Standard 老库升级需在停机后先运行 `MaterialClient.StandardMigrator.exe <dbPath>`，不再由客户端启动静默原地改表（这正是隔离目标：防止启动路径副作用与半残库风险）。
