## Context

`repos/MaterialClient` 的 4 个桌面宿主共享 `MaterialClientDbContext`（内核）与各自产品 DbContext（`StandardDbContext`、`SolidWasteDbContext`、`UrbanDbContext`、`RecycleDbContext`）。此前所有宿主均通过 `KernelDatabaseMigrator.MigrateAsync` + 产品 `Database.MigrateAsync()` 启动；同时仓内并存 `MaterialClient.Toolkit` 与 `MaterialClient.DatabaseUpgrade` 两个独立迁移工具。

经用户确认（D1–D5）：全新空库由本体创建；`MaterialClient.Toolkit` 已淘汰；固废现场已升级完毕且无后续升级需求；`Migrations` 仅服务于 Standard。

## Decisions

1. **移除退役项目**：
   - 从 `MaterialClient.sln` 移除 `MaterialClient.Toolkit` 与 `MaterialClient.DatabaseUpgrade` 项目条目及配置映射，并删除对应源码目录。
2. **新增静态 `SqliteSchemaBootstrap`（遵循 `minimal-di`，不注册 DI）**：
   - 位置：`repos/MaterialClient/src/MaterialClient.Common.EntityFrameworkCore/SqliteSchemaBootstrap.cs`。
   - 行为：
     - 解析内核 `MaterialClientDbContext` 与产品 `TProductDbContext`（共用当前 UoW 非事务连接）。
     - 若文件型 SQLite 尚不存在或缺失内核基表（`WeighingRecords`），调用 `MaterialClientDbContext` 的 `IRelationalDatabaseCreator.CreateTables()` 创建内核表。
     - 检查 `TProductDbContext` 模型中的所有表名；若缺失则调用 `TProductDbContext` 的 `IRelationalDatabaseCreator.CreateTables()` 创建产品表（规避 EF Core 第二个 DbContext 调 `EnsureCreated()` 时被跳过的行为）。
     - 统一调用 `SqliteMigrationHistoryMigrator.EnsureWalJournalModeAsync` 确保文件型库开启 `PRAGMA journal_mode = WAL;`。
     - 不调用 `RenameLegacyHistoryTableIfNeededAsync`，不调用 `Database.MigrateAsync()`。
3. **宿主分工**：
   - **Urban / Recycle**：启动调用 `SqliteSchemaBootstrap.EnsureInitializedAsync<UrbanDbContext / RecycleDbContext>`。
   - **SolidWaste**：全新库（`!HostStartupGate.ExistingDeployment`）调用 `SqliteSchemaBootstrap.EnsureInitializedAsync<SolidWasteDbContext>`；已有库仅确保 `WAL`。
   - **Standard**：维持 `KernelDatabaseMigrator.MigrateAsync` + `StandardDbContext.Database.MigrateAsync()` 不变。
4. **简化 `DeploymentPreflight` 与 `HostBootstrap`**：
   - `HostProduct.SolidWaste` 预检直接校验：内核必选表存在、`Settings` 产品身份为 `WeighingMode.SolidWaste`、`HasSolidWasteExtensions` 通过；不再强制要求 `__EFMigrationsHistory_Kernel` / `__EFMigrationsHistory_SolidWaste` 迁移记录，也不再提示运行已退役的 `MaterialClient.DatabaseUpgrade.exe`。
   - `HostProduct.Standard` 预检保持现有迁移基线校验不变。

## Risks / Trade-offs

- **删除工具的可回溯性**：`MaterialClient.Toolkit` 与 `MaterialClient.DatabaseUpgrade` 的完整代码永久保存在 git 历史中，必要时可按 commit 检出。
- **表结构演进约定**：Urban / Recycle / SolidWaste 不再走增量 `Migrations`，若未来确需对已部署现场库加字段，需明确通过新变更决定是否引入离线升级步骤或 SQL 补丁。
