## ADDED Requirements

### Requirement: Urban weighing extension entity
The system SHALL provide an `UrbanWeighingExtension` entity that stores Urban-specific properties for weighing records, maintaining a one-to-zero-or-one relationship with the base `WeighingRecord` entity.

#### Scenario: Extension entity structure
- **WHEN** the `UrbanWeighingExtension` entity is defined
- **THEN** it MUST contain a foreign key property `WeighingRecordId` referencing the parent `WeighingRecord`
- **AND** it MUST contain a `SyncStatus` property of type `SyncStatus` enum
- **AND** it MUST contain a `RetryCount` property of type `int` for tracking upload retry attempts
- **AND** it MUST contain a `LastErrorTime` property of type `DateTime?` for recording last failure timestamp

#### Scenario: Optional relationship
- **WHEN** a `WeighingRecord` exists without an extension
- **THEN** the system MUST allow the record to exist without requiring an `UrbanWeighingExtension` row
- **AND** the navigation property `UrbanExtension` on `WeighingRecord` MUST be nullable

### Requirement: Database relationship configuration
The system SHALL configure the one-to-zero-or-one relationship between `WeighingRecord` and `UrbanWeighingExtension` using Entity Framework Core Fluent API with appropriate constraints and indexes.

#### Scenario: Unique constraint
- **WHEN** the `UrbanWeighingExtension` table is configured
- **THEN** the `WeighingRecordId` column MUST have a unique constraint
- **AND** each `WeighingRecord` MUST have at most one related `UrbanWeighingExtension`

#### Scenario: Query performance indexes
- **WHEN** database indexes are created for the `UrbanWeighingExtension` table
- **THEN** a unique index MUST exist on `WeighingRecordId` for relationship integrity
- **AND** a composite index MUST exist on `(SyncStatus, WeighingRecordId)` for efficient background worker queries

### Requirement: Urban extension creation lifecycle
The system SHALL create an `UrbanWeighingExtension` row atomically with its parent `WeighingRecord` when an Urban mode weighing record is created.

#### Scenario: Extension creation on record creation
- **WHEN** a new `WeighingRecord` is created with `WeighingMode.UrbanMode`
- **THEN** the system MUST create a corresponding `UrbanWeighingExtension` row in the same transaction
- **AND** the extension MUST be initialized with `SyncStatus.Pending`
- **AND** the extension MUST be initialized with `RetryCount = 0`
- **AND** the extension MUST be initialized with `LastErrorTime = null`

#### Scenario: Extension absence for other modes
- **WHEN** a `WeighingRecord` is created with any mode other than `UrbanMode` (Standard, SolidWaste)
- **THEN** the system MUST NOT create an `UrbanWeighingExtension` row

#### Scenario: Transactional consistency
- **WHEN** creating a `WeighingRecord` with its extension
- **THEN** both entities MUST be saved in a single database transaction
- **AND** failure to save either entity MUST result in rollback of both entities

### Requirement: Query patterns for Urban extensions
The system SHALL provide efficient query patterns for accessing `WeighingRecord` entities with their Urban-specific extensions using LEFT JOIN semantics.

#### Scenario: List query with extensions
- **WHEN** the Urban variant queries weighing records for display
- **THEN** the query MUST use LEFT JOIN to include `UrbanWeighingExtension` data
- **AND** records without extensions MUST still be included in results (with null extension data)
- **AND** the query MUST filter by `WeighingMode == UrbanMode`

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
