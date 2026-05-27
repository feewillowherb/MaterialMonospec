## Purpose

Delta spec for `weighing-record-approval` capability, adding license plate validation and anomaly flag update requirements to the existing approval workflow.

## MODIFIED Requirements

### Requirement: ApproveRecordCommand on ViewModel
The `UrbanAttendedWeighingViewModel` SHALL provide an `ApproveRecordCommand` that accepts an `UrbanWeighingListItemDto` parameter, opens the edit dialog, validates the license plate, processes the result, and updates the anomaly flag.

#### Scenario: Successful approval with valid license plate
- **WHEN** `ApproveRecordCommand` executes with a valid `UrbanWeighingListItemDto`
- **THEN** a `WeighingRecordEditDialog` SHALL be created with the item's current values
- **AND** the dialog SHALL be shown modally via `ShowDialog`
- **AND** if the dialog returns a non-null result, the returned `PlateNumber` SHALL be validated using `PlateNumberValidator.IsValidChinesePlateNumber`
- **AND** if validation passes, `UpdateWeighingRecordAsync` SHALL be called with the record ID and edited values
- **AND** after successful update, `UpdateAnomalyFlagAsync` SHALL be called to recalculate the anomaly status
- **AND** the list SHALL be refreshed via `ReloadRecordsAsync`

#### Scenario: Approval rejected due to invalid license plate
- **WHEN** the dialog returns a result with an invalid `PlateNumber`
- **THEN** the system SHALL display an error message indicating the license plate format is invalid
- **AND** `UpdateWeighingRecordAsync` SHALL NOT be called
- **AND** the list SHALL remain unchanged

#### Scenario: Approval cancelled
- **WHEN** the dialog returns `null` (operator cancelled)
- **THEN** no service call SHALL be made
- **AND** the list SHALL remain unchanged

### Requirement: UpdateWeighingRecordAsync service method
The `IWeighingRecordService` SHALL provide an `UpdateWeighingRecordAsync` method that updates a weighing record's `PlateNumber` and `TotalWeight`, resets the associated `UrbanWeighingExtension.SyncStatus` to `Pending`, and updates the anomaly flag.

#### Scenario: Update record fields, reset sync status, and update anomaly flag
- **WHEN** `UpdateWeighingRecordAsync` is called with a valid `weighingRecordId`, `plateNumber`, and `totalWeight`
- **THEN** the `WeighingRecord` SHALL be fetched by ID
- **AND** `PlateNumber` SHALL be updated on the entity
- **AND** `TotalWeight` SHALL be updated on the entity
- **AND** the entity SHALL be persisted via the repository
- **AND** the associated `UrbanWeighingExtension` SHALL be located via `IUrbanWeighingExtensionService.GetByWeighingRecordIdAsync`
- **AND** if an extension exists, its `SyncStatus` SHALL be reset to `Pending` via `UpdateSyncStatusAsync`
- **AND** `UrbanAnomalyDetector.IsAnomaly` SHALL be called with the updated record
- **AND** `UpdateAnomalyFlagAsync` SHALL be called with the extension ID and calculated anomaly status

#### Scenario: Record not found
- **WHEN** `UpdateWeighingRecordAsync` is called with a non-existent `weighingRecordId`
- **THEN** the method SHALL throw or return an error indicating the record was not found

#### Scenario: No extension exists for record
- **WHEN** `UpdateWeighingRecordAsync` updates a record that has no `UrbanWeighingExtension` row
- **THEN** the record fields SHALL still be updated
- **AND** the sync status reset SHALL be skipped
- **AND** the anomaly flag update SHALL be skipped
- **AND** no error SHALL be thrown for the missing extension

#### Scenario: Transactional consistency
- **WHEN** `UpdateWeighingRecordAsync` executes
- **THEN** the WeighingRecord update, SyncStatus reset, and anomaly flag update SHALL occur within the same `UnitOfWork`
- **AND** failure of any subsequent operation SHALL NOT leave the record update partially committed

## ADDED Requirements

None. All enhancements are covered under MODIFIED requirements above.

## REMOVED Requirements

None.
