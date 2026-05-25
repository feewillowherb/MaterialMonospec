## MODIFIED Requirements

### Requirement: Urban weighing extension entity
The system SHALL provide an `UrbanWeighingExtension` entity that stores Urban-specific properties for weighing records. Association to `WeighingRecord` SHALL be expressed only as a scalar `WeighingRecordId` (`long`) without Entity Framework navigation properties on either entity and without database foreign-key constraints.

#### Scenario: Extension entity structure
- **WHEN** the `UrbanWeighingExtension` entity is defined
- **THEN** it MUST contain a `WeighingRecordId` property of type `long` referencing the parent record by identifier only (no ORM relationship mapping)
- **AND** it MUST NOT define a navigation property to `WeighingRecord`
- **AND** it MUST contain a `SyncStatus` property of type `SyncStatus` enum
- **AND** it MUST contain a `RetryCount` property of type `int` for tracking upload retry attempts
- **AND** it MUST contain a `LastErrorTime` property of type `DateTime?` for recording last failure timestamp

#### Scenario: Optional extension per record
- **WHEN** a `WeighingRecord` exists without an extension row
- **THEN** the system MUST allow the record to exist without requiring an `UrbanWeighingExtension` row
- **AND** `WeighingRecord` MUST NOT expose a mapped `UrbanExtension` navigation property

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
The system SHALL provide Urban list, filter, and background-worker queries through `IUrbanWeighingExtensionService` (or methods it exposes), combining `WeighingRecord` and `UrbanWeighingExtension` data in application code. Queries MUST NOT rely on EF `Include` of a navigation property from `WeighingRecord` to `UrbanWeighingExtension`.

#### Scenario: List query with extensions
- **WHEN** the Urban variant queries weighing records for display
- **THEN** `IUrbanWeighingExtensionService` MUST return records together with extension data (e.g. join or correlated load by `WeighingRecordId`)
- **AND** records without an extension row MUST still be included where applicable (extension fields null or default)
- **AND** the query MUST filter parent records by `WeighingMode == UrbanMode`

#### Scenario: Status-based filtering
- **WHEN** the Urban variant filters records by sync status (正常/异常/全部 tabs)
- **THEN** the query MUST filter based on `UrbanWeighingExtension.SyncStatus`
- **AND** the "正常" tab MUST show records where `SyncStatus != Failed`
- **AND** the "异常" tab MUST show records where `SyncStatus == Failed`
- **AND** the "全部" tab MUST show all records regardless of sync status

#### Scenario: Background worker query
- **WHEN** the background sync worker scans for pending uploads
- **THEN** the query MUST filter `UrbanWeighingExtension` where `SyncStatus == Pending`
- **AND** the query MUST utilize the composite index on `(SyncStatus, WeighingRecordId)` for performance

## ADDED Requirements

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
