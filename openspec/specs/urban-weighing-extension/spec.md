## Purpose

Defines the Urban Weighing Extension entity pattern that extends base `WeighingRecord` with Urban-specific properties (sync status, retry tracking). Association to the parent record is by scalar `WeighingRecordId` only—no EF navigation properties and no database foreign-key constraints—enabling clean separation of mode-specific concerns and explicit lifecycle control via `IUrbanWeighingExtensionService`.
## Requirements
### Requirement: Urban weighing extension entity
The system SHALL provide an `UrbanWeighingExtension` entity that stores Urban-specific properties for weighing records. Association to `WeighingRecord` SHALL be expressed only as a scalar `WeighingRecordId` (`long`) without Entity Framework navigation properties on either entity and without database foreign-key constraints. The entity SHALL implement `IHasExtraProperties` for storing extension data such as edit history.

#### Scenario: Extension entity structure
- **WHEN** the `UrbanWeighingExtension` entity is defined
- **THEN** it MUST contain a `WeighingRecordId` property of type `long` referencing the parent record by identifier only (no ORM relationship mapping)
- **AND** it MUST NOT define a navigation property to `WeighingRecord`
- **AND** it MUST contain a `SyncStatus` property of type `SyncStatus` enum
- **AND** it MUST contain a `RetryCount` property of type `int` for tracking upload retry attempts
- **AND** it MUST contain a `LastErrorTime` property of type `DateTime?` for recording last failure timestamp
- **AND** it MUST contain an `IsAnomaly` property of type `bool` for marking anomalous weighing records
- **AND** `IsAnomaly` 默认值 MUST 为 `false`
- **AND** it MUST implement `IHasExtraProperties` with an `ExtraProperties` property of type `ExtraPropertyDictionary`
- **AND** it MUST NOT contain a dedicated `EditHistoryJson` property or `[NotMapped] EditHistory` computed property

#### Scenario: Optional extension per record
- **WHEN** a `WeighingRecord` exists without an extension row
- **THEN** the system MUST allow the record to exist without requiring an `UrbanWeighingExtension` row
- **AND** the navigation property `UrbanExtension` on `WeighingRecord` MUST be nullable

### Requirement: Database relationship configuration
The system SHALL persist `UrbanWeighingExtension` in its own table with indexes for lookup and worker queries. The database MUST NOT declare a foreign-key constraint from `UrbanWeighingExtensions.WeighingRecordId` to `WeighingRecords.Id`. Entity Framework Core MUST NOT configure `HasOne`, `WithOne`, or `HasForeignKey` between these entities.

#### Scenario: No foreign key constraint
- **WHEN** the `UrbanWeighingExtensions` table is configured
- **THEN** the schema MUST NOT include a FOREIGN KEY on `WeighingRecordId`
- **AND** EF Fluent API MUST NOT register a relationship between `UrbanWeighingExtension` and `WeighingRecord`

#### Scenario: Unique constraint
- **WHEN** the `UrbanWeighingExtension` table is configured
- **THEN** the `WeighingRecordId` column MUST have a unique index
- **AND** at most one extension row MAY exist per `WeighingRecordId` value

#### Scenario: Query performance indexes
- **WHEN** database indexes are created for the `UrbanWeighingExtension` table
- **THEN** a unique index MUST exist on `WeighingRecordId`
- **AND** a composite index MUST exist on `(SyncStatus, WeighingRecordId)` for efficient background worker queries
- **AND** an index MUST exist on `IsAnomaly` for efficient tab filtering queries

#### Scenario: ExtraProperties column managed by ABP convention
- **WHEN** `UrbanWeighingExtension` implements `IHasExtraProperties`
- **THEN** the `ExtraProperties` column MUST be managed by ABP's `ConfigureByConvention()` (automatic JSON column)
- **AND** the Fluent API MUST NOT contain manual `EditHistoryJson` property configuration
- **AND** the Fluent API MUST NOT contain `entity.Ignore(e => e.EditHistory)` configuration

### Requirement: Urban extension creation lifecycle
The system SHALL create an `UrbanWeighingExtension` row when an Urban mode weighing record is created. Creation and association MUST be performed by `IUrbanWeighingExtensionService` (Domain Service), not by EF navigation or database cascades. The parent `WeighingRecord` MUST be persisted and assigned a non-zero `Id` before the extension row is inserted.

#### Scenario: Extension creation on record creation
- **WHEN** a new `WeighingRecord` is created with `WeighingMode.UrbanMode` and persisted with a valid `Id`
- **THEN** `IUrbanWeighingExtensionService` MUST create a corresponding `UrbanWeighingExtension` row with `WeighingRecordId` equal to that `Id`
- **AND** the extension MUST be initialized with `SyncStatus.Pending`
- **AND** the extension MUST be initialized with `RetryCount = 0`
- **AND** the extension MUST be initialized with `LastErrorTime = null`

#### Scenario: Extension absence for other modes
- **WHEN** a `WeighingRecord` is created with any mode other than `UrbanMode` (Standard, SolidWaste)
- **THEN** the system MUST NOT create an `UrbanWeighingExtension` row

#### Scenario: Transactional consistency
- **WHEN** creating a `WeighingRecord` with its extension in Urban mode
- **THEN** both operations MUST occur within the same application `UnitOfWork` transaction
- **AND** failure to save the extension after the parent record is saved MUST result in rollback of the unit of work
- **AND** the extension MUST NOT be inserted with `WeighingRecordId = 0`

### Requirement: Query patterns for Urban extensions
The system SHALL provide Urban list, filter, and background-worker queries through `IUrbanWeighingExtensionService` (or methods it exposes), combining `WeighingRecord` and `UrbanWeighingExtension` data in application code. Queries MUST NOT rely on EF `Include` of a navigation property from `WeighingRecord` to `UrbanWeighingExtension`. Paged list queries intended for the Urban attended weighing UI MUST accept a single input DTO and return `PagedResultDto` of list item DTOs, not entity instances. Tab filtering for the attended weighing list MUST follow `urban-anomaly-detection` and use `IsAnomaly`, not `SyncStatus.Failed`.

#### Scenario: List query with extensions
- **WHEN** the Urban variant queries weighing records for display
- **THEN** `IUrbanWeighingExtensionService` MUST execute a join (or equivalent) by `WeighingRecordId` and project results to `UrbanWeighingListItemDto` (or equivalent)
- **AND** the DTO MUST include `IsAnomaly` from the extension row (default false when extension is missing in projection rules)
- **AND** records without an extension row MUST still be included where applicable with appropriate default fields on the DTO
- **AND** the query MUST filter parent records by `WeighingMode == UrbanMode`
- **AND** the service MUST NOT assign or expose `WeighingRecord.UrbanExtension` navigation for UI consumption

#### Scenario: Paged list API shape
- **WHEN** the Urban attended weighing ViewModel requests a page of list data
- **THEN** the service method MUST accept one `GetUrbanWeighingListInput` (or equivalent) containing pagination and filter fields
- **AND** the method MUST return `PagedResultDto<UrbanWeighingListItemDto>`
- **AND** callers MUST NOT receive `PagedResultDto<WeighingRecord>` for this UI list path

#### Scenario: Tab filter by IsAnomaly
- **WHEN** the Urban variant filters records by the「正常/异常/全部」tabs
- **THEN** the「正常」tab MUST filter `UrbanWeighingExtension.IsAnomaly == false`
- **AND** the「异常」tab MUST filter `UrbanWeighingExtension.IsAnomaly == true`
- **AND** the「全部」tab MUST show all Urban mode records without filtering on `IsAnomaly`
- **AND** the query MUST NOT use `SyncStatus == Failed` as the definition of the「异常」tab

#### Scenario: Background worker query
- **WHEN** the background sync worker scans for pending uploads
- **THEN** the query MUST filter `UrbanWeighingExtension` where `SyncStatus == Pending`
- **AND** the query MUST utilize the composite index on `(SyncStatus, WeighingRecordId)` for performance

### Requirement: Urban extension domain service
The system SHALL provide `IUrbanWeighingExtensionService` as a Domain Service in `MaterialClient.Common` to own all create, read, and update operations on `UrbanWeighingExtension` and to orchestrate association with `WeighingRecord` by `WeighingRecordId`.

#### Scenario: Service registration and access
- **WHEN** the application starts
- **THEN** `IUrbanWeighingExtensionService` MUST be registered for dependency injection
- **AND** ViewModels MUST NOT inject `IRepository<UrbanWeighingExtension>` directly; they MUST use the Domain Service or a higher-level application service

#### Scenario: Create after parent id exists
- **WHEN** `CreateForRecordAsync` (or equivalent) is invoked with a valid `weighingRecordId > 0`
- **THEN** the service MUST insert one `UrbanWeighingExtension` row with that `WeighingRecordId`
- **AND** if an extension already exists for that `WeighingRecordId`, the service MUST NOT insert a duplicate (respect unique index)

#### Scenario: WeighingRecordService delegates extension creation
- **WHEN** `WeighingRecordService` creates an Urban mode weighing record
- **THEN** it MUST persist the `WeighingRecord` and obtain its `Id` before calling `IUrbanWeighingExtensionService`
- **AND** it MUST NOT insert `UrbanWeighingExtension` via `IRepository<UrbanWeighingExtension>` directly

### Requirement: Data migration preservation
The system SHALL preserve existing `SyncStatus` values when migrating from the old `WeighingRecord.SyncStatus` column to the new extension table pattern.

#### Scenario: Migration data transfer
- **WHEN** the database migration executes
- **THEN** all existing `WeighingRecord` rows with `WeighingMode == UrbanMode` MUST have their `SyncStatus` value copied to a new `UrbanWeighingExtension` row
- **AND** the new extension row MUST reference the correct `WeighingRecord.Id` as `WeighingRecordId`

#### Scenario: Backward compatibility preservation
- **WHEN** the migration completes
- **THEN** the old `SyncStatus` column MUST remain in the `WeighingRecords` table (SQLite does not support DROP COLUMN)
- **AND** the application code MUST ignore the old column and use the extension table exclusively

#### Scenario: Migration rollback capability
- **WHEN** a migration rollback is executed
- **THEN** the `UrbanWeighingExtensions` table MUST be dropped
- **AND** the old `SyncStatus` column data MUST remain intact for continued operation

### Requirement: Type safety and compile-time checking
The system SHALL provide compile-time type safety for Urban-specific weighing record properties through strong typing rather than dictionary-based storage. Edit history data stored in `ExtraProperties` SHALL be accessed through dedicated extension methods that provide type-safe access.

#### Scenario: Strong-typed property access
- **WHEN** application code accesses Urban-specific properties
- **THEN** core properties (SyncStatus, IsAnomaly, etc.) MUST be accessed as strongly-typed members (e.g., `extension.SyncStatus`)
- **AND** edit history MUST be accessed through extension methods (e.g., `extension.GetEditHistory()` returning `List<EditEntry>`)
- **AND** edit history MUST NOT be accessed through raw string-based dictionary lookups

#### Scenario: Compiler validation
- **WHEN** code is compiled
- **THEN** references to Urban-specific properties MUST be validated at compile-time
- **AND** typos or missing properties MUST cause compilation errors rather than runtime failures

### Requirement: Extension entity isolation and organization
The system SHALL organize Urban-specific domain entities within a dedicated folder structure in `MaterialClient.Common` to provide clear ownership boundaries.

#### Scenario: Folder organization
- **WHEN** Urban-specific entities are organized
- **THEN** `UrbanWeighingExtension` MUST reside in `MaterialClient.Common/Entities/Urban/` directory
- **AND** the namespace MUST be `MaterialClient.Common.Entities.Urban`
- **AND** the `SyncStatus` enum MUST remain in `MaterialClient.Common/Entities/Enums/` (shared location)

#### Scenario: DbContext unity
- **WHEN** the `MaterialClientDbContext` is configured
- **THEN** it MUST include a `DbSet<UrbanWeighingExtension>` property
- **AND** Fluent API configuration MUST reside in the same `OnModelCreating` method
- **AND** no separate DbContext or module replacement MUST be required

### Requirement: Edit history stored via ExtraProperties with extension methods
The system SHALL store edit history data for `UrbanWeighingExtension` in the `ExtraProperties` dictionary under the key `"EditHistory"`, accessed through type-safe extension methods following the same pattern as `SolidWasteInfoExtensions`.

#### Scenario: GetEditHistory extension method
- **WHEN** `extension.GetEditHistory()` is called on an `UrbanWeighingExtension` that has edit history stored in ExtraProperties
- **THEN** the method MUST deserialize the JSON string from `ExtraProperties["EditHistory"]` into `List<EditEntry>`
- **AND** if the key is missing or deserialization fails, it MUST return an empty `List<EditEntry>`
- **AND** each `EditEntry` in the list MUST contain: `ChangedAt` (DateTime), `PlateNumber` (string), `TotalWeight` (decimal), `AnomalyReason` (string?)

#### Scenario: SetEditHistory extension method
- **WHEN** `extension.SetEditHistory(entries)` is called with a non-empty list
- **THEN** the method MUST serialize the list to JSON and store it in `ExtraProperties["EditHistory"]`
- **AND** when called with `null` or an empty list, the method MUST remove the key or set it to `null`

#### Scenario: AppendEditEntryAsync uses extension methods
- **WHEN** `IUrbanWeighingExtensionService.AppendEditEntryAsync` is called with a complete snapshot of current field values (PlateNumber, TotalWeight, AnomalyReason)
- **THEN** the implementation MUST create a new `EditEntry` containing the full snapshot (ChangedAt, PlateNumber, TotalWeight, AnomalyReason)
- **AND** MUST append it to the existing history list via `GetEditHistory()` / `SetEditHistory()` extension methods
- **AND** the implementation MUST NOT reference `EditHistoryJson` or `EditHistory` properties directly

### Requirement: UrbanWeighingExtension 提交机器码字段

MaterialClient `UrbanWeighingExtension` 实体 SHALL 新增 `SubmitMachineCode`（可空字符串），记录客户端提交该称重数据时的机器码，用于数据溯源。提交时 SHALL 由 `MachineCodeService.GetMachineCode()`（或等价服务）写入本机机器码。

#### Scenario: 创建 Extension 时写入提交机器码

- **WHEN** 客户端创建/更新 `UrbanWeighingExtension` 准备上传
- **THEN** `SubmitMachineCode` SHALL 由本机 `MachineCodeService.GetMachineCode()` 填充
- **AND** 该值 SHALL 随上传 DTO 一并发送

#### Scenario: 上传 DTO 携带 submitMachineCode

- **WHEN** `UrbanServerUploadService` 构造 `UrbanWeighingRecordSubmitDto`
- **THEN** DTO SHALL 包含 `submitMachineCode` 字段
- **AND** 该字段 SHALL 取自 `UrbanWeighingExtension.SubmitMachineCode`

#### Scenario: 数据库列新增

- **WHEN** MaterialClient（SQLite）应用迁移
- **THEN** `UrbanWeighingExtensions` 表 SHALL 新增 `SubmitMachineCode TEXT NULL` 列
- **AND** 历史 NULL 值 SHALL 不阻断既有数据读取

