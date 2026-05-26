## MODIFIED Requirements

### Requirement: Urban weighing extension entity
The system SHALL provide an `UrbanWeighingExtension` entity that stores Urban-specific properties for weighing records, maintaining a one-to-zero-or-one relationship with the base `WeighingRecord` entity.

#### Scenario: Extension entity structure
- **WHEN** the `UrbanWeighingExtension` entity is defined
- **THEN** it MUST contain a foreign key property `WeighingRecordId` referencing the parent `WeighingRecord`
- **AND** it MUST contain a `SyncStatus` property of type `SyncStatus` enum
- **AND** it MUST contain a `RetryCount` property of type `int` for tracking upload retry attempts
- **AND** it MUST contain a `LastErrorTime` property of type `DateTime?` for recording last failure timestamp
- **AND** it MUST contain an `IsAnomaly` property of type `bool` for marking anomalous weighing records
- **AND** `IsAnomaly` 默认值 MUST 为 `false`

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
- **AND** an index MUST exist on `IsAnomaly` for efficient tab filtering queries

### Requirement: Extension entity isolation and organization
The system SHALL organize Urban-specific domain entities within a dedicated folder structure in `MaterialClient.Common` to provide clear ownership boundaries.

#### Scenario: Folder organization
- **WHEN** Urban-specific entities are organized
- **THEN** `UrbanWeighingExtension` MUST reside in `MaterialClient.Common/Entities/Urban/` directory
- **AND** the namespace MUST be `MaterialClient.Common.Entities.Urban`
- **AND** the `SyncStatus` enum MUST remain in `MaterialClient.Common/Entities/Enums/` (shared location)
