## 1. OpenSpec 与分支准备

- [x] 1.1 在主仓库创建变更 `fix-sqlite-wal-on-migration` 并通过 `openspec validate fix-sqlite-wal-on-migration --strict`
- [x] 1.2 在 `repos/MaterialClient` 从 `main` 切出同名分支 `fix-sqlite-wal-on-migration`（Mode A）

## 2. MaterialClient 代码实现

- [x] 2.1 修改 `repos/MaterialClient/src/MaterialClient.Common.EntityFrameworkCore/SqliteMigrationHistoryMigrator.cs`：文件型连接在目标 `.db` 文件不存在时不提前 `OpenAsync()`，并新增静态方法 `EnsureWalJournalModeAsync`
- [x] 2.2 修改 `repos/MaterialClient/src/MaterialClient.Common.EntityFrameworkCore/KernelDatabaseMigrator.cs`：在 `dbContext.Database.MigrateAsync()` 之后调用 `SqliteMigrationHistoryMigrator.EnsureWalJournalModeAsync`

## 3. 单元测试与 Graph 100 周期验证

- [x] 3.1 在 `repos/MaterialClient/tests/MaterialClient.Common.Tests/` 新增测试，覆盖全新文件库启用 WAL、存量 `DELETE` 库迁移后切回 WAL、legacy history table 重命名、`:memory:` 跳过
- [x] 3.2 运行相关单元测试并构建 `MaterialClient.Urban`（`Build-MaterialClient.Urban.ps1`）
- [x] 3.3 启动构建后的 `MaterialClient.Urban`（全新隔离库），使用 `pipelines/graphs/materialclient/fev-urban-weighing-cycles` 执行 100 周期称重验证并确认工作库为 `wal` 且核对 `SQLite Error 5` 与落库计数（Run `2026-11-25T085427`：`journal_mode=wal`，`100/100` 落库，`0` 次 `SQLite Error 5`）
