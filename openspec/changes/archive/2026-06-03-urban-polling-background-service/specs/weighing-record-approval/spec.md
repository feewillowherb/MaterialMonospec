## MODIFIED Requirements

### Requirement: ApproveRecordCommand on ViewModel

The `UrbanAttendedWeighingViewModel` SHALL provide an `ApproveRecordCommand` that accepts an `UrbanWeighingListItemDto` parameter, opens the edit dialog, validates the license plate, processes the result, and updates the anomaly flag. The command MUST NOT perform HTTP upload to UrbanManagement on the UI thread; upload SHALL be delegated to the Urban `PollingBackgroundService` after sync status is reset to `Pending`.

#### Scenario: Successful approval with valid license plate
- **WHEN** `ApproveRecordCommand` executes with a valid `UrbanWeighingListItemDto`
- **THEN** a `WeighingRecordEditDialog` SHALL be created with the item's current values
- **AND** the dialog SHALL be shown modally via `ShowDialog`
- **AND** if the dialog returns a non-null result, the returned `PlateNumber` SHALL be validated using `PlateNumberValidator.IsValidChinesePlateNumber`
- **AND** if validation passes, `UpdateWeighingRecordAsync` SHALL be called with the record ID and edited values
- **AND** after successful update, `UpdateAnomalyFlagAsync` SHALL be called to recalculate the anomaly status
- **AND** the list SHALL be refreshed via `ReloadRecordsAsync`
- **AND** `IUrbanServerUploadService.SubmitRecordAsync` SHALL NOT be invoked synchronously from the approval command path

#### Scenario: Approval rejected due to invalid license plate
- **WHEN** the dialog returns a result with an invalid `PlateNumber`
- **THEN** the system SHALL display an error message indicating the license plate format is invalid
- **AND** `UpdateWeighingRecordAsync` SHALL NOT be called
- **AND** the list SHALL remain unchanged

#### Scenario: Approval cancelled
- **WHEN** the dialog returns `null` (operator cancelled)
- **THEN** no service call SHALL be made
- **AND** the list SHALL remain unchanged

#### Scenario: Re-upload after approval via background worker
- **WHEN** approval succeeds and `UpdateWeighingRecordAsync` resets `SyncStatus` to `Pending`
- **THEN** the record SHALL become eligible for `GetPendingForUploadAsync`
- **AND** `MaterialClient.Urban.Backgrounds.PollingBackgroundService` SHALL upload the record on a subsequent worker tick when `BackgroundServices:Polling` is enabled and `IsAnomaly` is false
