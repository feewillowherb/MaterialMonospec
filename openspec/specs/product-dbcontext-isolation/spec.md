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

Urban and Recycle hosts SHALL apply pending kernel migrations before pending product migrations at startup. The Standard host SHALL apply kernel migrations, then `StandardDbContext` migrations. The SolidWaste host SHALL apply kernel migrations, then `SolidWasteDbContext` migrations, then SolidWaste extension backfill. The Standard host MUST NOT apply `SolidWasteDbContext`, `UrbanDbContext`, or `RecycleDbContext` migrations. The SolidWaste host MUST NOT apply `StandardDbContext`, `UrbanDbContext`, or `RecycleDbContext` migrations. Urban and Recycle hosts MUST NOT apply `StandardDbContext` or `SolidWasteDbContext` migrations.

#### Scenario: Urban startup migrate order

- **WHEN** Urban `OnApplicationInitializationAsync` runs database migration
- **THEN** it SHALL migrate `MaterialClientDbContext` first
- **AND** SHALL then migrate `UrbanDbContext`
- **AND** MUST NOT migrate `StandardDbContext` or `SolidWasteDbContext`

#### Scenario: Standard host does not migrate Urban schema

- **WHEN** the standard `MaterialClient` host applies EF migrations
- **THEN** it MUST NOT apply `UrbanDbContext` or `RecycleDbContext` migrations
- **AND** MUST NOT apply `SolidWasteDbContext` migrations

#### Scenario: Standard host migrates kernel then Standard

- **WHEN** the standard `MaterialClient` host applies startup migrations
- **THEN** it SHALL migrate `MaterialClientDbContext` first
- **AND** SHALL then migrate `StandardDbContext`

#### Scenario: SolidWaste host migrates kernel then SolidWaste

- **WHEN** the `MaterialClient.SolidWaste` host applies startup migrations
- **THEN** it SHALL migrate `MaterialClientDbContext` first
- **AND** SHALL then migrate `SolidWasteDbContext`
- **AND** SHALL then backfill missing SolidWaste extension rows

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

`SqliteMigrationHistoryMigrator.RenameLegacyHistoryTableIfNeededAsync` MUST NOT open or create a file-backed SQLite database when the target database file does not yet exist on disk. After applying kernel EF migrations on a file-backed SQLite database, `KernelDatabaseMigrator.MigrateAsync` SHALL ensure `PRAGMA journal_mode = WAL` is active. In-memory SQLite connections (`:memory:`) SHALL be skipped without error.

#### Scenario: Fresh file-backed database enables WAL on startup migration

- **WHEN** `KernelDatabaseMigrator.MigrateAsync` runs against a file-backed SQLite path that does not yet exist
- **THEN** `SqliteMigrationHistoryMigrator.RenameLegacyHistoryTableIfNeededAsync` MUST return without creating the file
- **AND** after migration completes, querying `PRAGMA journal_mode` on that database SHALL return `wal`

#### Scenario: Existing DELETE-mode database switches to WAL on startup migration

- **WHEN** `KernelDatabaseMigrator.MigrateAsync` runs against an existing file-backed SQLite database currently in `DELETE` journal mode
- **THEN** legacy history table migration SHALL still run when `__EFMigrationsHistory` is present
- **AND** after migration completes, querying `PRAGMA journal_mode` on that database SHALL return `wal`

#### Scenario: In-memory SQLite database skips file checks and WAL pragma

- **WHEN** `KernelDatabaseMigrator.MigrateAsync` or `SqliteMigrationHistoryMigrator` runs against an in-memory (`:memory:`) SQLite connection
- **THEN** it SHALL complete without throwing or attempting file-system checks on `:memory:`

