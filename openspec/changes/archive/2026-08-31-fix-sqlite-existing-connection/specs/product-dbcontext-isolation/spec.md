## ADDED Requirements

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
