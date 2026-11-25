## Why

当前 `repos/MaterialClient` 同时保留了已淘汰的 `MaterialClient.Toolkit`、已完成固废现场升级使命的 `MaterialClient.DatabaseUpgrade`，以及 4 个桌面宿主全部在启动时执行 EF `MigrateAsync()` 与 legacy history table 重命名的双轨结构。按 2026-11-25 架构讨论拍板（[`docs/2026-11-25-materialclient-upgrade-isolation/00-调研总览.md`](../../docs/2026-11-25-materialclient-upgrade-isolation/00-调研总览.md)）：
1. 全新空库由各客户端本体自行创建；
2. 仅 Standard 仍需保留 EF `Migrations`；
3. `MaterialClient.Toolkit` 已淘汰不再使用；
4. 固废现场已完成升级，后续无升级需求，`MaterialClient.DatabaseUpgrade` 可退役。

需要将退役工具移除，并将 Urban / Recycle / SolidWaste 的数据库启动路径简化为“空库由本体按最新模型建表 + WAL，已有库直接运行（SolidWaste 保留产品身份与表结构只读防错）”，使 `Migrations` 仅服务于 Standard。

## What Changes

- 从 `repos/MaterialClient/MaterialClient.sln` 与 `src/` 移除退役项目 `MaterialClient.Toolkit` 和 `MaterialClient.DatabaseUpgrade`。
- 在 `MaterialClient.Common.EntityFrameworkCore` 新增静态引导工具 `SqliteSchemaBootstrap.EnsureInitializedAsync<TProductDbContext>`：对非 Standard 宿主（Urban / Recycle / SolidWaste），全新空库时通过 `IRelationalDatabaseCreator.CreateTables()` 直接按当前模型创建内核与产品表并启用 `PRAGMA journal_mode = WAL`，已有库仅确保 `WAL` 而不执行增量 `MigrateAsync()` 与 legacy history table 重命名。
- 更新 `MaterialClientUrbanModule`、`MaterialClientRecycleModule`、`MaterialClientSolidWasteModule` 使用 `SqliteSchemaBootstrap.EnsureInitializedAsync<TProductDbContext>`；`MaterialClient`（Standard）保持既有 `KernelDatabaseMigrator` + `StandardDbContext.Database.MigrateAsync()` 不变。
- 更新 `DeploymentPreflight` 与 `HostBootstrap`：移除对退役 `MaterialClient.DatabaseUpgrade.exe` 的提示与固废历史迁移 ID 依赖，固废预检改为直接校验内核必选表、产品身份与固废扩展表结构（兼容已升级现场库与全新建表库）。
- 同步更新并补充单元测试。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `product-dbcontext-isolation`：明确 Urban / Recycle / SolidWaste 宿主启动时采用当前模型空库建表 + WAL 引导（不依赖增量 EF `Migrations` 与 legacy history table 重命名），EF `Migrations` 仅服务于 Standard 宿主；同时从解决方案移除退役迁移工具项目。

## Impact

- 影响子仓库：`repos/MaterialClient`（`MaterialClient.sln`、移除 `MaterialClient.Toolkit` 与 `MaterialClient.DatabaseUpgrade`、修改 `MaterialClient.Common.EntityFrameworkCore`、`MaterialClient.Common/Hosting`、`MaterialClient.Urban`、`MaterialClient.Recycle`、`MaterialClient.SolidWaste` 及 `MaterialClient.Common.Tests`）。
- `MaterialClient`（Standard）保持现有迁移路径不受影响。
