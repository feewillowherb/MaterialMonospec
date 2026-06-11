## MODIFIED Requirements

### Requirement: Anomaly flag update after approval
The system SHALL recalculate and update the anomaly flag after a weighing record is modified during approval.

#### Scenario: Anomaly flag recalculated on edit
- **WHEN** `UpdateWeighingRecordAsync` completes successfully with edited `PlateNumber` and `TotalWeight`
- **THEN** the system SHALL fetch the updated `WeighingRecord` entity
- **AND** the system SHALL fetch the associated `UrbanWeighingExtension` by `WeighingRecordId`
- **AND** `UrbanAnomalyDetector.IsAnomaly` SHALL be called with the updated record
- **AND** `UrbanAnomalyDetector.GetAnomalyReason` SHALL be called with the updated record
- **AND** `UpdateAnomalyFlagAsync` SHALL be called with the extension ID and calculated anomaly status
- **AND** the `IsAnomaly` flag SHALL be persisted to the database
- **AND** the `AnomalyReason` SHALL be recalculated and persisted to the database

#### Scenario: Anomaly status change reflected in UI
- **WHEN** the anomaly flag is updated after approval
- **THEN** `ReloadRecordsAsync` SHALL be called
- **AND** the UI list SHALL refresh to display the updated anomaly status
- **AND** records with `IsAnomaly=true` SHALL display "异常" badge
- **AND** records with `IsAnomaly=false` SHALL display "正常" badge

#### Scenario: Missing extension handling
- **WHEN** `UpdateWeighingRecordAsync` updates a record with no associated `UrbanWeighingExtension`
- **THEN** the anomaly flag update SHALL be skipped
- **AND** no error SHALL be thrown
- **AND** the record update SHALL complete successfully

## ADDED Requirements

### Requirement: Edit history appended on approval
The system SHALL append edit history entries to `UrbanWeighingExtension.EditHistoryJson` after a weighing record is successfully modified during approval.

#### Scenario: Edit entries appended after plate/weight edit
- **WHEN** `UpdateWeighingRecordAsync` completes successfully and the edited values differ from the original values
- **THEN** the system SHALL call `AppendEditEntryAsync` for each changed field (PlateNumber, TotalWeight)
- **AND** the old and new values SHALL be captured before the update is applied
- **AND** each entry SHALL include `changedAt` set to the current UTC timestamp

#### Scenario: No edit entry when values unchanged
- **WHEN** `UpdateWeighingRecordAsync` is called but the PlateNumber and TotalWeight values match the existing values
- **THEN** no edit entry SHALL be appended
