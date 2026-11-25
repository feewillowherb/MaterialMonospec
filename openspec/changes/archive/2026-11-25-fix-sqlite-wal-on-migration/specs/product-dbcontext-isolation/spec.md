## ADDED Requirements

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
