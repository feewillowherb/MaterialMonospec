## MODIFIED Requirements

### Requirement: ApproveRecordCommand on ViewModel

The `UrbanAttendedWeighingViewModel` SHALL provide an `ApproveRecordCommand` that accepts an `UrbanWeighingListItemDto` parameter, opens the edit dialog, validates the license plate, processes the result, and updates the anomaly flag. The command MUST NOT perform HTTP upload to UrbanManagement on the UI thread. After a successful local approval update, upload SHALL be requested by publishing `UrbanWeighingUploadRequestedEventData` via `ILocalEventBus` for immediate background sync of that record; `PollingBackgroundService` SHALL remain the fallback for retries and batch pending scans. The command MUST NOT invoke `ApproveWeighingRecordAsync`, `ApproveAsync`, or synchronously await `SubmitRecordAsync`.

#### Scenario: Successful approval with valid license plate

- **WHEN** `ApproveRecordCommand` executes with a valid `UrbanWeighingListItemDto`
- **THEN** a `WeighingRecordEditDialog` SHALL be created with the item's current values
- **AND** the dialog SHALL be shown modally via `ShowDialog`
- **AND** if the dialog returns a non-null result, the returned `PlateNumber` SHALL be validated using `PlateNumberValidator.IsValidChinesePlateNumber`
- **AND** if validation passes, `UpdateWeighingRecordAsync` SHALL be called with the record ID and edited values
- **AND** after successful update, `UpdateAnomalyFlagAsync` SHALL be called to recalculate the anomaly status
- **AND** the list SHALL be refreshed via `ReloadRecordsAsync`
- **AND** `IUrbanServerUploadService.SubmitRecordAsync` SHALL NOT be invoked synchronously from the approval command path
- **AND** after successful local update with `SyncStatus == Pending` and `IsAnomaly == false`, SHALL publish `UrbanWeighingUploadRequestedEventData` for immediate background upload
- **AND** `ApproveWeighingRecordAsync` (or equivalent Approve Refit method) SHALL NOT be invoked from the approval command path

#### Scenario: Re-upload after approval via immediate event with polling fallback

- **WHEN** approval succeeds and `UpdateWeighingRecordAsync` resets `SyncStatus` to `Pending` and clears anomaly (`IsAnomaly == false`)
- **THEN** the ViewModel SHALL publish `UrbanWeighingUploadRequestedEventData` with the approved `WeighingRecordId`
- **AND** the upload event handler SHALL attempt `SubmitRecordAsync` for that record without blocking the UI
- **AND** if immediate upload fails, `PollingBackgroundService` SHALL still upload the record on a subsequent worker tick when polling is enabled
- **AND** server sync SHALL use `ReceiveWeighingRecordAsync` (upsert by `ClientRecordId`), not an Approve API

#### Scenario: Re-upload after approval via background worker only when immediate path skipped

- **WHEN** approval succeeds but immediate upload event is not published (e.g. `IsAnomaly == true`)
- **THEN** the record SHALL become eligible for `GetPendingForUploadAsync` only after anomaly is cleared
- **AND** `PollingBackgroundService` SHALL upload when eligible

---

## ADDED Requirements

### Requirement: Client approval orchestrates local Lrp changes without Approve API

`UrbanAttendedWeighingViewModel.ApproveRecordAsync` (or the approval command handler) SHALL coordinate client-side approval so that Lrp adopt and file-replace actions persist local attachments through the Service layer, record edit history with `IsImagesModified` when applicable, publish `UrbanWeighingUploadRequestedEventData` after successful local approval for immediate background sync, and rely on `PollingBackgroundService` as fallback. It SHALL NOT call UrbanManagement approval APIs or synchronously await upload HTTP on the UI thread.

#### Scenario: Approve after adopt creates local Lrp only

- **WHEN** the operator clicks「采纳」in the approval dialog and then confirms approval
- **THEN** local Lrp attachment creation SHALL have occurred before or during Save via Service layer
- **AND** `UpdateWeighingRecordAsync` SHALL update plate/weight and reset `SyncStatus` to `Pending`
- **AND** SHALL publish `UrbanWeighingUploadRequestedEventData` when the record is eligible for upload (`IsAnomaly == false`)
- **AND** `IUrbanServerUploadService.SubmitRecordAsync` SHALL NOT be invoked on the UI thread
- **AND** `ApproveWeighingRecordAsync` / `ApproveAsync` SHALL NOT be called

#### Scenario: Approve without Lrp changes unchanged

- **WHEN** the operator confirms approval without adopt or Lrp file replace
- **THEN** the approval flow SHALL update local fields and reset `SyncStatus` to `Pending` only
- **AND** background upload SHALL sync via `ReceiveAsync` as today

#### Scenario: Dialog tracks whether local Lrp was modified

- **WHEN** the approval dialog session included successful local Lrp create or replace
- **THEN** the ViewModel or Service SHALL pass that fact to edit-history append logic so `IsImagesModified` is set on the new edit entry

---

## REMOVED Requirements

### Requirement: Client approval invokes ApproveWeighingRecordAsync

**Reason**: Client approval syncs via `UpdateWeighingRecordAsync` + `ReceiveAsync` upsert; `ApproveAsync` is Web-only. The `approval-image-replacement-capture-anomaly` path that passed `LrpReplacementBase64` / `UrbanPhotoReplacementBase64` (and plate/weight) through `ApproveWeighingRecordAsync` duplicates `ReceiveAsync` and violates non-blocking upload rules.

**Migration**: Remove `await api.ApproveWeighingRecordAsync(...)` from `UrbanAttendedWeighingViewModel`; remove `ApproveWeighingRecordAsync` from `IUrbanManagementApi` if present; remove `UrbanWeighingRecordApproveDto` client usage for approval.
