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

### Requirement: Edit result return type
The dialog SHALL return a strongly-typed result object containing the edited fields.

#### Scenario: EditResult structure
- **WHEN** the dialog Save command executes
- **THEN** a result object SHALL be created containing `PlateNumber` (`string`) and `TotalWeight` (`decimal`)
- **AND** the result SHALL be passed to `Close(result)` for the calling ViewModel to consume

### Requirement: 审批弹窗展示只读称重日期

`WeighingRecordEditDialog` SHALL 新增只读称重日期字段，供审批时核对记录时间。

#### Scenario: 打开弹窗显示称重日期
- **WHEN** 操作员点击异常记录“审批”并打开编辑弹窗
- **THEN** 弹窗 MUST 显示该记录的称重日期字段
- **AND** 称重日期字段 MUST 为只读不可编辑

#### Scenario: 关闭与提交不修改称重日期
- **WHEN** 操作员保存或取消审批
- **THEN** 审批流程 MUST NOT 修改称重日期原始值

### Requirement: 审批前确认交互

审批保存操作 SHALL 在持久化前弹出确认框，确认后才执行更新。

#### Scenario: 确认后执行更新
- **WHEN** 操作员点击“确定”并在确认框选择“确认”
- **THEN** 系统 MUST 执行审批更新流程

#### Scenario: 拒绝确认不更新
- **WHEN** 操作员在确认框选择“取消”
- **THEN** 系统 MUST 中止审批更新流程
- **AND** 记录数据 MUST 保持不变

### Requirement: Client approval re-upload updates server record

After a successful client-side approval that resets `SyncStatus` to `Pending`, the subsequent background upload via `ReceiveAsync` SHALL update the corresponding server-side `UrbanWeighingRecord` identified by `ClientRecordId`, not merely return the existing server Id without field changes.

#### Scenario: End-to-end approval sync

- **WHEN** a weighing record was previously uploaded to UrbanManagement with incorrect `PlateNumber` or `TotalWeight` and `IsAnomaly: true`
- **AND** the operator completes client-side approval with valid plate and weight
- **AND** `UpdateWeighingRecordAsync` resets local `SyncStatus` to `Pending`
- **AND** `PollingBackgroundService` uploads the record on a subsequent tick
- **THEN** UrbanManagement MUST persist the corrected `PlateNumber` and `TotalWeight` on the existing server record
- **AND** the server record's `IsAnomaly` MUST reflect the client's post-approval value
- **AND** if the client reports `IsAnomaly: false`, the server record MUST have `SyncType = 0` so it re-enters the government sync queue

#### Scenario: Local Synced reflects server update

- **WHEN** the background upload completes successfully after client approval
- **THEN** the client SHALL mark local `SyncStatus` as `Synced`
- **AND** querying UrbanManagement for that `ClientRecordId` MUST return the same plate and weight as the approved local record

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

### Requirement: Client applies server approval sync locally

MaterialClient.Urban SHALL apply server approval sync messages (from SignalR push or pull API) to local weighing records via the Service layer inside a Unit of Work.

#### Scenario: Apply server approval from push

- **WHEN** the client receives a `WeighingRecordApproved` SignalR message for `ClientRecordId`
- **THEN** the Service layer SHALL update local `PlateNumber` and `TotalWeight` to the pushed values
- **AND** SHALL set local `IsAnomaly` to `false` and clear `AnomalyReason`
- **AND** SHALL set local `SyncStatus` to `Synced`
- **AND** SHALL call the server ACK API to set `ClientApprovalAckAt`
- **AND** SHALL publish a local event to refresh the weighing list UI

#### Scenario: Apply server approval from pull on startup

- **WHEN** the application starts or SignalR reconnects
- **AND** the pull API returns pending server approvals for this `ProId`
- **THEN** the client SHALL apply each pending record using the same local application logic as push
- **AND** SHALL ACK each successfully applied record

#### Scenario: Idempotent apply when already synced

- **WHEN** a server approval sync message arrives for a record that is already locally non-anomalous with matching plate and weight
- **THEN** the client MAY skip field updates
- **AND** SHALL still invoke ACK if server `ClientApprovalAckAt` is null

### Requirement: Disable client approval after server approval applied

The Urban weighing list SHALL disable or hide the「审批」action for records that have been updated by server approval sync.

#### Scenario: Approval button disabled after server sync

- **WHEN** local `IsAnomaly == false` because server approval sync was applied
- **THEN** the list row MUST NOT expose an enabled「审批」control

#### Scenario: Approval dialog interrupted by server sync

- **WHEN** the operator has the approval dialog open
- **AND** a server approval sync message arrives for the same `WeighingRecordId`
- **THEN** the system SHALL notify the operator that the record was approved on the server
- **AND** SHALL close the dialog without persisting local approval changes

### Requirement: Relaxed client-server approval conflict

When server approval sync and client local approval overlap, MaterialClient SHALL NOT implement strict conflict arbitration. Either outcome is acceptable.

#### Scenario: Client upload after server approval

- **WHEN** the client later performs local approval and uploads via `ReceiveAsync` after server approval was applied locally
- **THEN** the existing client upload and server upsert flow SHALL proceed without client-side blocking solely due to prior server approval sync

