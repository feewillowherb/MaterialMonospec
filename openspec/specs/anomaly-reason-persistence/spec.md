# anomaly-reason-persistence Specification

## Purpose
TBD - created by archiving change anomaly-reason-repair-history. Update Purpose after archive.
## Requirements
### Requirement: AnomalyReason persistent field on UrbanWeighingExtension
The system SHALL persist `AnomalyReason` as a `string?` property on `UrbanWeighingExtension` (MaterialClient) and `UrbanWeighingRecord` (UrbanManagement). The value SHALL be written at record creation time and recalculated on approval edits.

#### Scenario: AnomalyReason populated on creation
- **WHEN** a new `UrbanWeighingExtension` is created via `CreateForRecordAsync`
- **THEN** the system SHALL call `UrbanAnomalyDetector.GetAnomalyReason` with the parent `WeighingRecord` and anomaly configuration
- **AND** the result SHALL be assigned to `AnomalyReason` on the extension entity
- **AND** the extension SHALL be persisted with the `AnomalyReason` value

#### Scenario: AnomalyReason null for non-anomalous records
- **WHEN** a new `UrbanWeighingExtension` is created and the record is NOT anomalous
- **THEN** `AnomalyReason` SHALL be `null`

#### Scenario: AnomalyReason recalculated on approval
- **WHEN** `ApproveAsync` modifies `PlateNumber` or `TotalWeight` on a record
- **THEN** the system SHALL re-evaluate `IsAnomaly` using the updated values
- **AND** if the record is still anomalous, `AnomalyReason` SHALL be updated to the new reason
- **AND** if the record is no longer anomalous, `AnomalyReason` SHALL be set to `null`

#### Scenario: AnomalyReason stored in database column
- **WHEN** the `UrbanWeighingExtensions` table schema is configured
- **THEN** the `AnomalyReason` column SHALL be `NVARCHAR(32)` (UrbanManagement) / `TEXT` (MaterialClient SQLite)
- **AND** the column SHALL be nullable

### Requirement: AnomalyReason synchronized to UrbanManagement server
The system SHALL transmit `AnomalyReason` from MaterialClient to UrbanManagement via the upload API and persist it on `UrbanWeighingRecord`.

#### Scenario: ReceiveAsync persists AnomalyReason
- **WHEN** `ReceiveAsync` receives a record with a non-null `AnomalyReason`
- **THEN** the system SHALL store the value on the `UrbanWeighingRecord.AnomalyReason` property
- **AND** the value SHALL be persisted to the database

#### Scenario: ReceiveAsync handles null AnomalyReason
- **WHEN** `ReceiveAsync` receives a record with `AnomalyReason == null`
- **THEN** the system SHALL store `null` on the `UrbanWeighingRecord.AnomalyReason` property
- **AND** no error SHALL be thrown

### Requirement: AnomalyReason displayed in UrbanManagement list
The system SHALL display `AnomalyReason` in the UrbanManagement weighing record list for anomalous records.

#### Scenario: AnomalyReason shown for anomalous records
- **WHEN** the weighing record list renders a row with `IsAnomaly == true` and `AnomalyReason` is not null
- **THEN** the `AnomalyReason` value SHALL be displayed in the list row

#### Scenario: Placeholder for non-anomalous records
- **WHEN** the weighing record list renders a row with `IsAnomaly == false`
- **THEN** the AnomalyReason column SHALL display `--` or equivalent placeholder

### Requirement: AnomalyReason read from persisted field in list query
The system SHALL read `AnomalyReason` from the persisted `UrbanWeighingExtension.AnomalyReason` field during list queries, not recompute it at query time.

#### Scenario: List query uses persisted AnomalyReason
- **WHEN** `GetPagedListItemsAsync` builds the `UrbanWeighingListItemDto`
- **THEN** `AnomalyReason` SHALL be read from `x.Extension.AnomalyReason`
- **AND** the system SHALL NOT call `UrbanAnomalyDetector.GetAnomalyReason` during list query construction

