## MODIFIED Requirements

### Requirement: Host applies kernel migrations then product migrations

The Standard host SHALL apply pending kernel migrations before pending `StandardDbContext` migrations at startup and MUST NOT apply `SolidWasteDbContext`, `UrbanDbContext`, or `RecycleDbContext` migrations. Urban, Recycle, and SolidWaste hosts SHALL initialize fresh databases directly from their current kernel and product EF models via `SqliteSchemaBootstrap.EnsureInitializedAsync` and enable WAL mode on file-backed SQLite databases, without running incremental EF migrations or legacy migration history table renames. Urban, Recycle, and SolidWaste hosts MUST NOT apply `StandardDbContext` migrations or another product's schema.

#### Scenario: Urban fresh startup initializes kernel and Urban tables with WAL

- **WHEN** Urban runs database bootstrap against a non-existent file-backed SQLite path
- **THEN** it SHALL create `MaterialClientDbContext` tables and `UrbanDbContext` tables directly from the current models
- **AND** SHALL enable `PRAGMA journal_mode = WAL`
- **AND** MUST NOT execute legacy history table rename or incremental EF migrations

#### Scenario: Recycle fresh startup initializes kernel and Recycle tables with WAL

- **WHEN** Recycle runs database bootstrap against a non-existent file-backed SQLite path
- **THEN** it SHALL create `MaterialClientDbContext` tables and `RecycleDbContext` tables directly from the current models
- **AND** SHALL enable `PRAGMA journal_mode = WAL`

#### Scenario: SolidWaste fresh and existing startup without incremental migrations

- **WHEN** `MaterialClient.SolidWaste` runs against a fresh database path
- **THEN** it SHALL create `MaterialClientDbContext` tables and `SolidWasteDbContext` tables directly from the current models and enable WAL
- **AND** when `MaterialClient.SolidWaste` opens an existing SolidWaste database, `DeploymentPreflight` SHALL validate required kernel tables, SolidWaste product identity, and SolidWaste extension tables without requiring EF migration history tables or retired upgrade tools

#### Scenario: Standard host migrates kernel then Standard

- **WHEN** the standard `MaterialClient` host applies startup migrations
- **THEN** it SHALL migrate `MaterialClientDbContext` first
- **AND** SHALL then migrate `StandardDbContext`
- **AND** MUST NOT apply `SolidWasteDbContext`, `UrbanDbContext`, or `RecycleDbContext` migrations

## ADDED Requirements

### Requirement: Retired migration and upgrade tools are removed from the solution

`MaterialClient.Toolkit` and `MaterialClient.DatabaseUpgrade` SHALL be removed from `MaterialClient.sln` and `repos/MaterialClient/src/`, and host preflight diagnostics MUST NOT instruct operators to run `MaterialClient.DatabaseUpgrade.exe`.

#### Scenario: Solution builds without retired migration tool projects

- **WHEN** `MaterialClient.sln` is inspected or built
- **THEN** neither `MaterialClient.Toolkit` nor `MaterialClient.DatabaseUpgrade` SHALL be present in the solution
