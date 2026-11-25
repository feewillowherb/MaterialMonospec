## MODIFIED Requirements

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

### Requirement: File-backed SQLite startup migration preserves and enables WAL journal mode

`SqliteSchemaBootstrap.EnsureInitializedAsync` and `SqliteSchemaBootstrap.EnsureWalJournalModeAsync` SHALL ensure `PRAGMA journal_mode = WAL` is active on file-backed SQLite databases and SHALL skip `:memory:` SQLite connections without error. `MaterialClient.StandardMigrator` MUST NOT pre-create a non-existent SQLite file before migration and SHALL ensure `PRAGMA journal_mode = WAL` after migrating.

#### Scenario: Existing DELETE-mode database switches to WAL on startup or standalone migration

- **WHEN** `SqliteSchemaBootstrap.EnsureWalJournalModeAsync` or `MaterialClient.StandardMigrator` runs against an existing file-backed SQLite database currently in `DELETE` journal mode
- **THEN** querying `PRAGMA journal_mode` on that database afterward SHALL return `wal`

#### Scenario: In-memory SQLite database skips WAL pragma without error

- **WHEN** `SqliteSchemaBootstrap.EnsureWalJournalModeAsync` runs against an in-memory (`:memory:`) SQLite connection
- **THEN** it SHALL complete without throwing or attempting file-system checks on `:memory:`
