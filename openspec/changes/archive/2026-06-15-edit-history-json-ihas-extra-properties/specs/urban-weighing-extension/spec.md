## MODIFIED Requirements

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

## ADDED Requirements

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
