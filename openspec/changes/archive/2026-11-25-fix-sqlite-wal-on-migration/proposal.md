## Why

`KernelDatabaseMigrator.MigrateAsync` 在调用 `dbContext.Database.MigrateAsync()` 之前先调用 `SqliteMigrationHistoryMigrator.RenameLegacyHistoryTableIfNeededAsync`。当目标 SQLite 文件尚不存在时，`RenameLegacyHistoryTableIfNeededAsync` 直接调用 `sqlite.OpenAsync()`（默认 `ReadWriteCreate`）提前创建了 0 字节空文件，导致 EF Core 的 `SqliteDatabaseCreator.Exists()` 判定库已存在并跳过 `Create()`（从而跳过 EF Core 自动执行的 `PRAGMA journal_mode = 'wal'`）。结果所有 2026-08-28 之后新建的客户端 SQLite 数据库均停留在 `DELETE` 日志模式，在 Urban 100 周期连续称重压测中与后台轮询/扫描并发时触发 `SQLite Error 5: 'database is locked'` 并丢失称重记录（实测 97/100）。

## What Changes

- 在 `SqliteMigrationHistoryMigrator.RenameLegacyHistoryTableIfNeededAsync` 中，对于文件型且尚未打开的 SQLite 连接，若目标 `.db` 文件尚未存在则直接返回，不再提前创建空文件。
- 在 `KernelDatabaseMigrator.MigrateAsync` 完成内核迁移后，对文件型 SQLite 数据库显式执行 `PRAGMA journal_mode = WAL;`，确保新建库以及此前停留在 `DELETE` 模式的存量库均启用 WAL 模式（内存库 `:memory:` 跳过）。
- 补充针对真实 SQLite 文件的单元测试，验证全新迁移和存量 `DELETE` 库迁移后 `PRAGMA journal_mode` 均为 `wal`，且不破坏既有 legacy history table 重命名逻辑。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `product-dbcontext-isolation`：补充内核迁移对文件型 SQLite 数据库保留/启用 WAL 日志模式的约束，禁止迁移前置检查在建库前提前创建空 `.db` 文件。

## Impact

- 影响子仓库：`repos/MaterialClient`（`MaterialClient.Common.EntityFrameworkCore` 及其单元测试）。
- 影响所有复用 `KernelDatabaseMigrator.MigrateAsync` 的桌面宿主（`MaterialClient.Urban`、`MaterialClient.SolidWaste`、`MaterialClient.Recycle`、`MaterialClient` Standard）。
- 仅在运行时启动迁移时开启 WAL，不影响独立固废升级工具 `MaterialClient.DatabaseUpgrade` 导出便携单文件时的 `DELETE` 收口约定。
