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
- **AND** it MUST contain an `IsAnomaly` property of type `bool` for marking anomalous weighing records
- **AND** `IsAnomaly` 默认值 MUST 为 `false`
- **AND** it MUST contain an `AnomalyReason` property of type `string?` for persisting the anomaly detection reason
- **AND** it MUST contain a `EditHistoryJson` property of type `string?` for storing modification history as a JSON array
- **AND** it MUST contain a `[NotMapped]` `EditHistory` computed property of type `List<EditEntry>` for typed access to the modification history
