## ADDED Requirements

### Requirement: GovProject entity uses ABP Entity base class
`GovProject` SHALL inherit from `Entity<Guid>` with properties mapped to PascalCase English names: `Id` (Guid), `ProName` (string), `BuildLicenseNo` (string?), `FdBuildLicenseNo` (string?), `AddTime` (DateTime?), `SyncStatus` (bool?), `LastSyncTime` (DateTime?), `DeleteStatus` (bool?). The entity SHALL NOT use SqlSugar annotations.

#### Scenario: Entity can be instantiated with required fields
- **WHEN** a new `GovProject` is created with a name
- **THEN** `ProName` SHALL be set and `Id` SHALL be a non-empty Guid

#### Scenario: Entity has no SqlSugar dependencies
- **WHEN** `GovProject.cs` is inspected
- **THEN** it SHALL NOT import any `SqlSugar` namespace

### Requirement: GovSyncData entity uses ABP Entity base class
`GovSyncData` SHALL inherit from `Entity<int>` with properties: `CarNo` (string?), `CarColor` (string?), `CarNoColor` (string?), `CarType` (string?), `SnapTime` (string?), `DeviceId` (string?), `BuildLicenseNo` (string?), `SiteType` (string?), `GoodsWeight` (string?), `SourceData` (string?), `AddTime` (DateTime?), `ProId` (string?), `ProName` (string?), `SyncType` (int?), `SyncTime` (DateTime?), `SyncNumber` (int?), `SnapImages` (string?).

#### Scenario: Entity properties use PascalCase
- **WHEN** `GovSyncData.cs` is inspected
- **THEN** all property names SHALL be PascalCase (e.g., `SnapTime` not `snapTime`)

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
