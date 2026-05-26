## Purpose

Defines the approval workflow for Urban weighing records: the edit dialog UI, the ViewModel command that orchestrates the flow, and the service method that persists field edits and resets sync status.

## Requirements

### Requirement: Weighing record edit dialog
The system SHALL provide a `WeighingRecordEditDialog` window that allows the operator to modify the `PlateNumber` and `TotalWeight` of a weighing record during approval. The dialog SHALL follow the `AddCameraDialog` pattern with dedicated ViewModel, code-behind command subscription, and `Close(result)` on Save/Cancel.

#### Scenario: Dialog opens with current record values
- **WHEN** the operator clicks the "审批" button on a weighing record row
- **THEN** the dialog SHALL open as a modal window centered on the parent
- **AND** the `PlateNumber` TextBox SHALL be pre-populated with the record's current `PlateNumber`
- **AND** the `TotalWeight` TextBox SHALL be pre-populated with the record's current `TotalWeight` formatted to 2 decimal places

#### Scenario: Operator edits and saves
- **WHEN** the operator modifies the PlateNumber or TotalWeight and clicks "确定"
- **THEN** the dialog SHALL close and return an `EditResult` object containing the updated `PlateNumber` and `TotalWeight`
- **AND** the `TotalWeight` value in the result SHALL be a valid `decimal`

#### Scenario: Operator cancels
- **WHEN** the operator clicks "取消" or closes the dialog window
- **THEN** the dialog SHALL close and return `null`
- **AND** no changes SHALL be persisted

#### Scenario: TotalWeight validation
- **WHEN** the operator enters a non-numeric or negative value in the TotalWeight field and clicks "确定"
- **THEN** the Save command SHALL NOT proceed
- **AND** the dialog SHALL remain open

### Requirement: ApproveRecordCommand on ViewModel
The `UrbanAttendedWeighingViewModel` SHALL provide an `ApproveRecordCommand` that accepts an `UrbanWeighingListItemDto` parameter, opens the edit dialog, and processes the result.

#### Scenario: Successful approval with edits
- **WHEN** `ApproveRecordCommand` executes with a valid `UrbanWeighingListItemDto`
- **THEN** a `WeighingRecordEditDialog` SHALL be created with the item's current values
- **AND** the dialog SHALL be shown modally via `ShowDialog`
- **AND** if the dialog returns a non-null result, `UpdateWeighingRecordAsync` SHALL be called with the record ID and edited values
- **AND** the list SHALL be refreshed via `ReloadRecordsAsync`

#### Scenario: Approval cancelled
- **WHEN** the dialog returns `null` (operator cancelled)
- **THEN** no service call SHALL be made
- **AND** the list SHALL remain unchanged

### Requirement: UpdateWeighingRecordAsync service method
The `IWeighingRecordService` SHALL provide an `UpdateWeighingRecordAsync` method that updates a weighing record's `PlateNumber` and `TotalWeight`, and resets the associated `UrbanWeighingExtension.SyncStatus` to `Pending`.

#### Scenario: Update record fields and reset sync status
- **WHEN** `UpdateWeighingRecordAsync` is called with a valid `weighingRecordId`, `plateNumber`, and `totalWeight`
- **THEN** the `WeighingRecord` SHALL be fetched by ID
- **AND** `PlateNumber` SHALL be updated on the entity
- **AND** `TotalWeight` SHALL be updated on the entity
- **AND** the entity SHALL be persisted via the repository
- **AND** the associated `UrbanWeighingExtension` SHALL be located via `IUrbanWeighingExtensionService.GetByWeighingRecordIdAsync`
- **AND** if an extension exists, its `SyncStatus` SHALL be reset to `Pending` via `UpdateSyncStatusAsync`

#### Scenario: Record not found
- **WHEN** `UpdateWeighingRecordAsync` is called with a non-existent `weighingRecordId`
- **THEN** the method SHALL throw or return an error indicating the record was not found

#### Scenario: No extension exists for record
- **WHEN** `UpdateWeighingRecordAsync` updates a record that has no `UrbanWeighingExtension` row
- **THEN** the record fields SHALL still be updated
- **AND** no sync status reset SHALL be attempted
- **AND** no error SHALL be thrown for the missing extension

#### Scenario: Transactional consistency
- **WHEN** `UpdateWeighingRecordAsync` executes
- **THEN** the WeighingRecord update and SyncStatus reset SHALL occur within the same `UnitOfWork`
- **AND** failure of the sync status reset SHALL NOT leave the record update partially committed

### Requirement: Edit result return type
The dialog SHALL return a strongly-typed result object containing the edited fields.

#### Scenario: EditResult structure
- **WHEN** the dialog Save command executes
- **THEN** a result object SHALL be created containing `PlateNumber` (`string`) and `TotalWeight` (`decimal`)
- **AND** the result SHALL be passed to `Close(result)` for the calling ViewModel to consume
