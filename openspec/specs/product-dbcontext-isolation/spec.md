# Product DbContext Isolation Specification

## Purpose

定义内核与产品双（多）DbContext、独立 migration history、无跨 Context FK、启动迁移顺序。
## Requirements
### Requirement: Kernel and product use separate DbContext types on one SQLite file

The kernel SHALL use `MaterialClientDbContext` for baseline tables only. Urban SHALL use `UrbanDbContext` for Urban tables only. Recycle SHALL use `RecycleDbContext` for Recycle tables only. All three SHALL use the same SQLite connection string (`Default` / existing local db file). The runtime MUST NOT use ABP `ReplaceDbContext` to merge product entity types into the kernel context model.

#### Scenario: Kernel model excludes product tables

- **WHEN** the kernel `OnModelCreating` for `MaterialClientDbContext` is applied
- **THEN** the model MUST NOT include `UrbanWeighingExtension` or `RecycleWaybillExtension`

#### Scenario: Product context excludes kernel aggregate mapping for migrations

- **WHEN** `UrbanDbContext` is used to generate or apply migrations
- **THEN** those migrations MUST NOT create or alter kernel tables such as `WeighingRecords` or `Waybills`
- **AND** Urban code that needs kernel data SHALL use kernel repositories or kernel services, not kernel `DbSet`s on `UrbanDbContext` as the migration owner

### Requirement: Separate EF migration history tables

Each DbContext SHALL record applied migrations in a distinct SQLite table: `__EFMigrationsHistory_Kernel`, `__EFMigrationsHistory_Urban`, and `__EFMigrationsHistory_Recycle` (names MAY vary only if documented in the module, but MUST be unique per context).

#### Scenario: Product migration does not collide with kernel history

- **WHEN** Urban applies a product migration after kernel migrations
- **THEN** the product history table SHALL record the Urban migration
- **AND** the kernel history table MUST NOT treat that Urban migration as a kernel migration

### Requirement: Host applies kernel migrations then product migrations

All four desktop hosts (`MaterialClient` Standard, `MaterialClient.SolidWaste`, `MaterialClient.Urban`, and `MaterialClient.Recycle`) SHALL initialize fresh databases directly from their current kernel and product EF models via `SqliteSchemaBootstrap.EnsureInitializedAsync` and enable WAL mode on file-backed SQLite databases, and MUST NOT execute incremental EF `MigrateAsync()` or legacy migration history table renames at runtime. Standard legacy database migration (`MaterialClientDbContext` then `StandardDbContext`, including legacy `__EFMigrationsHistory` rename) SHALL be isolated in the standalone `MaterialClient.StandardMigrator` executable.

#### Scenario: Standard fresh startup initializes kernel and Standard tables with WAL

- **WHEN** the standard `MaterialClient` host runs against a non-existent file-backed SQLite path
- **THEN** it SHALL create `MaterialClientDbContext` tables and `StandardDbContext` tables directly from the current models
- **AND** SHALL enable `PRAGMA journal_mode = WAL`
- **AND** MUST NOT execute legacy history table rename or incremental EF migrations

#### Scenario: Standalone StandardMigrator upgrades a legacy Standard database

- **WHEN** `MaterialClient.StandardMigrator` runs against an existing Standard SQLite file
- **THEN** it SHALL rename legacy `__EFMigrationsHistory` to `__EFMigrationsHistory_Kernel` when present
- **AND** SHALL migrate `MaterialClientDbContext` first and `StandardDbContext` second
- **AND** SHALL verify `PRAGMA integrity_check` and enable `PRAGMA journal_mode = WAL`

### Requirement: No cross-context database foreign keys

Product extension entities SHALL continue to associate to kernel rows by logical identifiers only. The system MUST NOT introduce EF navigations or database foreign keys from product tables to kernel tables.

#### Scenario: Extension upsert by logical id

- **WHEN** an Urban service persists `UrbanWeighingExtension` for a weighing record
- **THEN** it SHALL set `WeighingRecordId` without requiring a database FK to `WeighingRecords`

### Requirement: Urban settings are not a kernel SettingsEntity column

`SettingsEntity.UrbanSettingsJson` SHALL NOT remain a required kernel baseline column. Urban settings persistence SHALL be owned by `UrbanDbContext`.

#### Scenario: Kernel settings entity without Urban blob requirement

- **WHEN** the kernel settings mapping is applied after this change
- **THEN** Urban-specific settings MUST NOT be required on `SettingsEntity` for the kernel model to be valid
- **AND** the Urban host SHALL read and write Urban settings via Urban product persistence

### Requirement: Same UnitOfWork reuses one SQLite connection across kernel and product DbContexts

When more than one of `MaterialClientDbContext`, `UrbanDbContext`, and `RecycleDbContext` participate in the same ABP ambient UnitOfWork and the same `Default` connection string, each context's `AbpDbContextOptions` configuration MUST call `UseSqlite` with `AbpDbContextConfigurationContext.ExistingConnection` when that property is not null. The runtime MUST NOT replace `IUnitOfWork`, `IUnitOfWorkManager`, or `IDbContextProvider<T>` to achieve multi-context commits. The runtime MUST NOT use `ReplaceDbContext` to merge product entity types into the kernel model.

#### Scenario: Second context joins existing transaction connection

- **WHEN** an ambient UnitOfWork already holds an EF transaction on the Default SQLite database
- **AND** a second DbContext type for that same connection string is resolved inside that UnitOfWork
- **THEN** that second context MUST be configured with the existing `DbConnection` instance
- **AND** ABP MUST be able to attach it with `UseTransaction` instead of beginning a second write transaction on a new connection

#### Scenario: No ambient transaction uses connection string

- **WHEN** a DbContext is configured and `ExistingConnection` is null
- **THEN** the module SHALL continue to call `UseSqlite` with the host's fixed Default connection string
- **AND** SHALL keep the context-specific migrations history table name (`__EFMigrationsHistory_Kernel`, `__EFMigrationsHistory_Urban`, or `__EFMigrationsHistory_Recycle`)

### Requirement: File-backed SQLite startup migration preserves and enables WAL journal mode

`SqliteSchemaBootstrap.EnsureInitializedAsync` and `SqliteSchemaBootstrap.EnsureWalJournalModeAsync` SHALL ensure `PRAGMA journal_mode = WAL` is active on file-backed SQLite databases and SHALL skip `:memory:` SQLite connections without error. `MaterialClient.StandardMigrator` MUST NOT pre-create a non-existent SQLite file before migration and SHALL ensure `PRAGMA journal_mode = WAL` after migrating.

#### Scenario: Existing DELETE-mode database switches to WAL on startup or standalone migration

- **WHEN** `SqliteSchemaBootstrap.EnsureWalJournalModeAsync` or `MaterialClient.StandardMigrator` runs against an existing file-backed SQLite database currently in `DELETE` journal mode
- **THEN** querying `PRAGMA journal_mode` on that database afterward SHALL return `wal`

#### Scenario: In-memory SQLite database skips WAL pragma without error

- **WHEN** `SqliteSchemaBootstrap.EnsureWalJournalModeAsync` runs against an in-memory (`:memory:`) SQLite connection
- **THEN** it SHALL complete without throwing or attempting file-system checks on `:memory:`

### Requirement: Retired migration and upgrade tools are removed from the solution

`MaterialClient.Toolkit` and `MaterialClient.DatabaseUpgrade` SHALL be removed from `MaterialClient.sln` and `repos/MaterialClient/src/`, and host preflight diagnostics MUST NOT instruct operators to run `MaterialClient.DatabaseUpgrade.exe`.

#### Scenario: Solution builds without retired migration tool projects

- **WHEN** `MaterialClient.sln` is inspected or built
- **THEN** neither `MaterialClient.Toolkit` nor `MaterialClient.DatabaseUpgrade` SHALL be present in the solution

