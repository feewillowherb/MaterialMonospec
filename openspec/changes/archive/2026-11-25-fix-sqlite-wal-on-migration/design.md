## Context

`KernelDatabaseMigrator.MigrateAsync` 被 Urban、SolidWaste、Recycle、Standard 四个桌面宿主共享。历史提交 `88924fd5` 为支持从旧 `__EFMigrationsHistory` 表迁移到 `__EFMigrationsHistory_Kernel`，在 `dbContext.Database.MigrateAsync()` 之前加入了 `SqliteMigrationHistoryMigrator.RenameLegacyHistoryTableIfNeededAsync`。由于该方法未检查物理 `.db` 文件是否存在就直接 `OpenAsync()`，新建库会被提前创建为 `DELETE` 模式，导致 EF Core 跳过 `SqliteDatabaseCreator.Create()` 中的 `PRAGMA journal_mode = 'wal'`。

## Decisions

1. **在 `SqliteMigrationHistoryMigrator.RenameLegacyHistoryTableIfNeededAsync` 中先检查文件存在性**：
   - 使用 `SqliteConnectionStringBuilder(sqlite.ConnectionString).DataSource` 解析数据源。
   - 若连接尚未打开且数据源既非空也非 `:memory:`（且非 `file::memory:` / `mode=memory`），在 `!File.Exists(dataSource)` 时直接返回，避免提前创建空库文件。
   - 若连接已打开（如测试传入的已打开内存连接）或文件已存在，保持原有 legacy 表检测与重命名逻辑。
2. **在 `KernelDatabaseMigrator.MigrateAsync` 迁移完成后显式确保 WAL**：
   - 在 `SqliteMigrationHistoryMigrator` 中提供静态方法 `EnsureWalJournalModeAsync(DbContext dbContext, CancellationToken cancellationToken = default)`（遵循 `minimal-di`，不注册 DI 服务）。
   - 对文件型 SQLite 数据库执行 `PRAGMA journal_mode = WAL;`；对 `:memory:` 内存库直接跳过。
   - 这样不仅全新库由 EF Core 自动开启 WAL，2026-08-28 之后已部署但停留在 `DELETE` 模式的存量库（以及固废升级工具导出的单文件 `DELETE` 库）在首次启动后也会自动切回 `WAL`。

## Risks / Trade-offs

- **WAL 伴生文件**：运行期会重新出现 `MaterialClient.db-wal` / `MaterialClient.db-shm`，这与历史部署一致；独立升级工具备份/迁移时仍需遵守应用退出并释放连接的既有部署约束。
- **不替代写串行化**：WAL 解决读-写并发互不阻塞，但写-写仍互斥；进程内写串行化仍由 `fix-materialclient-sqlite-write-contention` 跟踪。
