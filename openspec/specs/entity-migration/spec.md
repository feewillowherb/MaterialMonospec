# Entity Migration

## Purpose

Defines the domain entities, enum types, and EF Core DbContext configuration migrated from the original SqlSugar-based data model to ABP + EF Core.

## Requirements

### Requirement: GovProject entity uses ABP Entity base class
`GovProject` SHALL inherit from `Entity<Guid>` with properties mapped to PascalCase English names: `Id` (Guid), `ProName` (string), `BuildLicenseNo` (string?), `AddTime` (DateTime?), `SyncStatus` (bool?), `LastSyncTime` (DateTime?), `DeleteStatus` (bool?). The entity SHALL NOT include `FdBuildLicenseNo`. The entity SHALL NOT use SqlSugar annotations.

#### Scenario: Entity can be instantiated with required fields
- **WHEN** a new `GovProject` is created with a name
- **THEN** `ProName` SHALL be set and `Id` SHALL be a non-empty Guid
- **AND** MUST NOT expose an `FdBuildLicenseNo` property

#### Scenario: Entity has no SqlSugar dependencies
- **WHEN** `GovProject.cs` is inspected
- **THEN** it SHALL NOT import any `SqlSugar` namespace

#### Scenario: EF model excludes FdBuildLicenseNo column
- **WHEN** the EF Core model for `GovProject` is configured
- **THEN** the `Gov_Project` table MUST NOT include an `FdBuildLicenseNo` column

### Requirement: GovSyncData entity uses ABP Entity base class
`GovSyncData` SHALL inherit from `Entity<int>` with properties including `ProId` as **non-nullable `Guid`** (legacy read-only rows). Other legacy string fields remain until a separate strong-type change. The entity SHALL NOT receive new inserts in Modern or Legacy WIP paths.

#### Scenario: GovSyncData ProId is Guid column

- **WHEN** the EF Core model for `GovSyncData` is configured
- **THEN** `ProId` SHALL map to a non-nullable Guid-compatible column
- **AND** historical string values SHALL be converted in migration where parseable

#### Scenario: Entity has no SqlSugar dependencies

- **WHEN** `GovSyncData.cs` is inspected
- **THEN** it SHALL NOT import any `SqlSugar` namespace

### Requirement: GovLog entity uses ABP Entity base class
`GovLog` SHALL inherit from `Entity<int>` with properties: `SyncId` (int?), `SyncTime` (DateTime?), `SyncNumber` (int?), `SyncSource` (string?), `SyncResult` (string?), `SyncCode` (string?), `SyncMsg` (string?).

#### Scenario: Entity is defined without SqlSugar annotations
- **WHEN** `GovLog.cs` is inspected
- **THEN** it SHALL NOT contain `[SugarTable]` or `[SugarColumn]` attributes

### Requirement: SyncStatus enum uses English identifiers
`SyncStatus` enum SHALL define `Pending = 0`, `Success = 1`, `Failed = 2` (English names replacing original Chinese names 待同步/同步成功/同步失败).

#### Scenario: Enum values are English
- **WHEN** `SyncStatus.Pending.ToString()` is called
- **THEN** it SHALL return `"Pending"`

### Requirement: UrbanManagementDbContext configures all entities
`UrbanManagementDbContext` SHALL inherit from `AbpDbContext<UrbanManagementDbContext>`, expose `DbSet<GovProject>`, `DbSet<GovSyncData>`, and `DbSet<GovLog>`, and configure table mappings (`Gov_Project`, `Gov_SyncData`, `Gov_Log`) via Fluent API in `OnModelCreating`.

#### Scenario: DbSet properties are available
- **WHEN** `UrbanManagementDbContext` is inspected
- **THEN** it SHALL have `DbSet<GovProject> GovProjects`, `DbSet<GovSyncData> GovSyncData`, and `DbSet<GovLog> GovLogs`

#### Scenario: Table names match original schema
- **WHEN** EF Core generates SQL
- **THEN** `GovProject` SHALL map to table `Gov_Project`, `GovSyncData` to `Gov_SyncData`, `GovLog` to `Gov_Log`

### Requirement: All code files use English identifiers only
All entity classes, properties, enums, and namespace names SHALL use English characters exclusively. No Chinese characters SHALL appear in identifiers.

#### Scenario: No Chinese characters in code identifiers
- **WHEN** any `.cs` file in the Core project is scanned
- **THEN** all identifier names SHALL contain only ASCII characters

### Requirement: UrbanWeighingRecord SiteType column is UrbanSiteType int

EF Core mapping for `UrbanWeighingRecord.SiteType` SHALL use non-nullable `UrbanSiteType` stored as integer. A migration MUST convert historical string values to enum integers before enforcing non-nullable int storage. Unparseable or null historical values MUST become `Construction` (0). The CLR property name MUST remain `SiteType`.

#### Scenario: Migration maps known wire strings

- **WHEN** the SiteType migration runs against a row with `SiteType = '2'`
- **THEN** the row SHALL store integer value for `UrbanSiteType.Disposal`

#### Scenario: Migration defaults unknown values

- **WHEN** the SiteType migration runs against a row with null or unrecognized `SiteType` text
- **THEN** the row SHALL store `UrbanSiteType.Construction` (0)

### Requirement: GovProject IsSyncEnabled is non-nullable bool

`GovProject` SHALL expose **`IsSyncEnabled`** as a non-nullable `bool` with default `false`. The database column MUST be named `IsSyncEnabled` (renamed from `EnableSync`). Historical NULL values MUST become `false` before the non-nullable constraint. The entity MUST NOT retain an `EnableSync` property.

#### Scenario: New project defaults sync off

- **WHEN** a `GovProject` is created via create or pull insert
- **THEN** `IsSyncEnabled` SHALL be `false` unless explicitly set otherwise

#### Scenario: Migration renames column and clears nulls

- **WHEN** the rename migration runs
- **THEN** former `EnableSync` NULL rows SHALL become `false`
- **AND** the persisted column name SHALL be `IsSyncEnabled`

### Requirement: GovSyncData SnapTime and GoodsWeight are strongly typed

`GovSyncData` SHALL expose **`SnapTime`** as `DateTime?` and **`GoodsWeight`** as `decimal?`. The database columns MUST retain the same names. Historical string values MUST be migrated by best-effort parse; values that cannot be parsed MUST become `NULL`. The entity MUST NOT keep these two properties as `string?`. The table remains **read-only** for new business inserts (no new rows from modern or Legacy paths as established by prior changes).

#### Scenario: Entity property types

- **WHEN** `GovSyncData.cs` is inspected
- **THEN** `SnapTime` SHALL be `DateTime?`
- **AND** `GoodsWeight` SHALL be `decimal?`

#### Scenario: Migration parses or nulls historical strings

- **WHEN** the strong-type migration runs against existing `GovSyncData` rows
- **THEN** parseable `SnapTime` strings SHALL become `DateTime` values
- **AND** parseable `GoodsWeight` strings SHALL become `decimal` values
- **AND** unparseable values SHALL become `NULL`
- **AND** column names SHALL remain `SnapTime` and `GoodsWeight`

#### Scenario: Fluent configuration matches types

- **WHEN** `UrbanManagementDbContext` configures `GovSyncData`
- **THEN** it MUST NOT apply string `HasMaxLength` constraints to `SnapTime` or `GoodsWeight`
