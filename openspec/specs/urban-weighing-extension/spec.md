## Purpose

Defines the Urban Weighing Extension entity pattern that extends base `WeighingRecord` with Urban-specific properties (sync status, retry tracking). Association to the parent record is by scalar `WeighingRecordId` only—no EF navigation properties and no database foreign-key constraints—enabling clean separation of mode-specific concerns and explicit lifecycle control via `IUrbanWeighingExtensionService`.

## Requirements

### Requirement: Urban weighing extension entity
The system SHALL provide an `UrbanWeighingExtension` entity that stores Urban-specific properties for weighing records. Association to `WeighingRecord` SHALL be expressed only as a scalar `WeighingRecordId` (`long`) without Entity Framework navigation properties on either entity and without database foreign-key constraints.

#### Scenario: Extension entity structure
- **WHEN** the `UrbanWeighingExtension` entity is defined
- **THEN** it MUST contain a `WeighingRecordId` property of type `long` referencing the parent record by identifier only (no ORM relationship mapping)
- **AND** it MUST NOT define a navigation property to `WeighingRecord`
- **AND** it MUST contain a `SyncStatus` property of type `SyncStatus` enum
- **AND** it MUST contain a `RetryCount` property of type `int` for tracking upload retry attempts
- **AND** it MUST contain a `LastErrorTime` property of type `DateTime?` for recording last failure timestamp
- **AND** it MUST contain an `IsAnomaly` property of type `bool` for marking anomalous weighing records
- **AND** `IsAnomaly` 默认值 MUST 为 `false`

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
The system SHALL provide compile-time type safety for Urban-specific weighing record properties through strong typing rather than dictionary-based storage.

#### Scenario: Strong-typed property access
- **WHEN** application code accesses Urban-specific properties
- **THEN** properties MUST be accessed as strongly-typed members (e.g., `extension.SyncStatus`)
- **AND** properties MUST NOT be accessed through string-based dictionary lookups (e.g., `ExtraProperties["SyncStatus"]`)

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
