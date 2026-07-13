## MODIFIED Requirements



### Requirement: Approval image replacement API on server



`UrbanWeighingRecordAppService.ApproveAsync` SHALL accept an optional `LrpReplacementBase64` field on `UrbanWeighingRecordApproveInputDto` for **UrbanManagement Web** approval. When the field is non-null and non-empty, the system SHALL create or replace the Lrp attachment for the record being approved. The system SHALL NOT modify UrbanPhoto attachments during approval. MaterialClient.Urban SHALL NOT use this field for client-side approval; client Lrp changes SHALL sync via attachment upload and `ReceiveAsync` per `urban-client-attachment-sync`.



#### Scenario: Lrp replacement provided via Web approval



- **WHEN** `ApproveAsync` is called from the Web UI with `LrpReplacementBase64` that is non-null and non-empty

- **THEN** the system SHALL call `IFileService.ReplaceAttachmentAsync` with `recordId`, `AttachType.Lrp`, and the Base64 string

- **AND** existing `AttachmentFile` and `UrbanWeighingRecordAttachment` rows for that record with `AttachType.Lrp` SHALL be deleted

- **AND** the old Lrp image file on disk SHALL be deleted

- **AND** a new `AttachmentFile` SHALL be created with the decoded image saved to disk

- **AND** a new `UrbanWeighingRecordAttachment` SHALL link the new `AttachmentFile` to the record



#### Scenario: Web Lrp replacement from adopted UrbanPhoto image



- **WHEN** `ApproveAsync` is called with `LrpReplacementBase64` containing the UrbanPhoto image bytes (operator clicked adopt on Web)

- **THEN** the system SHALL treat the payload identically to a file-picker Lrp replacement

- **AND** SHALL create a new Lrp attachment via `ReplaceAttachmentAsync` with `AttachType.Lrp`

- **AND** the existing UrbanPhoto attachment and file SHALL remain unchanged



#### Scenario: No Lrp replacement provided



- **WHEN** `ApproveAsync` is called with `LrpReplacementBase64` null or empty

- **THEN** the system SHALL NOT modify any attachments

- **AND** existing attachment rows and files SHALL remain unchanged



#### Scenario: Replacement within same UnitOfWork as approval



- **WHEN** Lrp image replacement and record update both occur during Web approval

- **THEN** all database changes (attachment deletion, attachment creation, record update, edit history append) SHALL participate in the same UnitOfWork

- **AND** a failure in replacement SHALL roll back the entire approval transaction



#### Scenario: Legacy UrbanPhoto replacement field ignored



- **WHEN** `ApproveAsync` is called with a non-null, non-empty legacy `UrbanPhotoReplacementBase64` field (if still present on the DTO)

- **THEN** the system SHALL NOT modify UrbanPhoto attachments

- **AND** approval SHALL proceed normally for other fields and Lrp replacement if provided



---



### Requirement: Client-side image replacement in approval dialog



The `WeighingRecordEditDialog` in MaterialClient.Urban SHALL allow the operator to modify Lrp images only during the approval editing process. UrbanPhoto previews SHALL be read-only. Client Lrp modifications SHALL be persisted as local `AttachType.Lrp` attachments via the Service layer and SHALL NOT be sent as `LrpReplacementBase64` to `ApproveAsync`.



#### Scenario: Replace Lrp image via file picker on client



- **WHEN** the operator clicks the replace button on the Lrp photo preview area

- **THEN** the system SHALL open a native file picker dialog filtered to image files (JPEG, PNG, BMP)

- **AND** upon file selection, the system SHALL persist the image as a local `AttachType.Lrp` attachment linked to the weighing record via `IAttachmentService` (or an approved Service)

- **AND** the Lrp preview SHALL update to show the new local file path

- **AND** the UrbanPhoto attachment SHALL remain unchanged



#### Scenario: Adopt UrbanPhoto as Lrp on client creates local Lrp attachment



- **WHEN** the approval dialog opens with `LprPhotoPath` null or empty and `CameraPhotoPath` not null or empty

- **THEN** the Lrp preview area SHALL display an「采纳」button in addition to the「替换」button

- **WHEN** the operator clicks「采纳」

- **THEN** the system SHALL call the Service layer to create a local `AttachType.Lrp` attachment from the existing UrbanPhoto attachment file (copy or equivalent persist under Lrp storage rules)

- **AND** SHALL link the new `AttachmentFile` to the weighing record via `WeighingRecordAttachment`

- **AND** the Lrp preview SHALL update to show the new Lrp local path

- **AND** the UrbanPhoto preview and attachment SHALL remain unchanged and read-only

- **AND** the system SHALL NOT populate `LrpReplacementBase64` on `EditResult`



#### Scenario: Client adopt does not upload on UI thread



- **WHEN** the operator clicks「采纳」and local Lrp creation succeeds

- **THEN** the system SHALL NOT call UrbanManagement attachment upload or `ApproveAsync` on the UI thread

- **AND** upload SHALL occur only after approval confirmation resets `SyncStatus` to `Pending` and `PollingBackgroundService` runs `SubmitRecordAsync`



#### Scenario: Adopt button hidden when Lrp already exists



- **WHEN** the approval dialog opens with `LprPhotoPath` not null or empty

- **THEN** the「采纳」button SHALL NOT be displayed

- **AND** only the Lrp「替换」button SHALL be available for Lrp modification



#### Scenario: Adopt button hidden when UrbanPhoto is empty



- **WHEN** the approval dialog opens with `CameraPhotoPath` null or empty

- **THEN** the「采纳」button SHALL NOT be displayed regardless of Lrp state



#### Scenario: UrbanPhoto is read-only in approval dialog



- **WHEN** the approval edit dialog renders the UrbanPhoto preview section

- **THEN** the UrbanPhoto area SHALL NOT display a replace or adopt button

- **AND** the operator SHALL NOT be able to modify UrbanPhoto through the approval dialog



#### Scenario: Cancel file selection



- **WHEN** the operator dismisses the file picker without selecting a file

- **THEN** the Lrp photo preview and local Lrp attachment SHALL remain unchanged from before the picker opened



#### Scenario: Replace Lrp when original is empty via file picker



- **WHEN** the operator clicks the replace button on the Lrp area that has no original image (placeholder shown)

- **THEN** the system SHALL open the file picker and, upon selection, create a local Lrp attachment

- **AND** the preview SHALL update from placeholder to the selected image



#### Scenario: Replace Lrp and then replace again on client



- **WHEN** the operator replaces or adopts an Lrp image and then clicks the Lrp replace button again

- **THEN** the system SHALL allow a second replacement via file picker

- **AND** SHALL replace the local Lrp attachment with the newly selected file

- **AND** the preview SHALL show the most recent Lrp image



---



### Requirement: EditResult carries replacement image data



The `WeighingRecordEditDialogViewModel.EditResult` record on MaterialClient.Urban SHALL NOT carry `LrpReplacementBase64` or UrbanPhoto replacement data. Lrp image changes SHALL already be persisted locally before or when the dialog closes with a successful Save.



#### Scenario: EditResult after local Lrp adopt or replace



- **WHEN** the operator confirms the approval dialog after adopting or replacing the Lrp image locally

- **THEN** `EditResult` SHALL contain only the edited weighing fields (e.g. `PlateNumber`, `TotalWeight`)

- **AND** SHALL NOT contain `LrpReplacementBase64` or `UrbanPhotoReplacementBase64`



#### Scenario: EditResult without Lrp modification



- **WHEN** the operator confirms the approval dialog without any local Lrp create or replace

- **THEN** `EditResult` SHALL contain only the edited weighing fields

- **AND** no image Base64 fields SHALL be present



---



### Requirement: Client passes replacement images to server approval call



`UrbanAttendedWeighingViewModel.ApproveRecordAsync` on MaterialClient.Urban SHALL NOT call `ApproveWeighingRecordAsync`, `ApproveAsync`, or pass any approval DTO to UrbanManagement on the UI thread. After approval confirmation, local field and attachment changes SHALL reach UrbanManagement through `IUrbanServerUploadService.SubmitRecordAsync` (attachment upload + `ReceiveAsync`) when `SyncStatus` is `Pending`.



#### Scenario: Client approval after local Lrp adopt or replace



- **WHEN** `ApproveRecordAsync` completes after the operator adopted or replaced Lrp locally in the dialog

- **THEN** the ViewModel SHALL call `UpdateWeighingRecordAsync` without invoking any Approve API

- **AND** SHALL reset `SyncStatus` to `Pending` so the new local Lrp is included in the next upload

- **AND** `PollingBackgroundService` SHALL upload the local Lrp attachment to UrbanManagement before or with `ReceiveWeighingRecordAsync`



#### Scenario: Client approval without Lrp modification



- **WHEN** `ApproveRecordAsync` completes without local Lrp changes

- **THEN** the upload pipeline SHALL behave as today (upload existing attachments only)

- **AND** SHALL NOT invoke `ApproveWeighingRecordAsync`



---



## REMOVED Requirements



### Requirement: Approval image replacement API on server — UrbanPhoto replacement scenarios



**Reason**: UrbanPhoto is original site evidence and must not be replaced during approval.



**Migration**: Remove `UrbanPhotoReplacementBase64` from `UrbanWeighingRecordApproveInputDto` and stop calling `ReplaceAttachmentAsync` with `AttachType.UrbanPhoto` in `ApproveAsync`. Legacy clients sending the field are ignored server-side.



---



### Requirement: Client-side image replacement in approval dialog — UrbanPhoto replace scenarios



**Reason**: UrbanPhoto is read-only in the approval workflow.



**Migration**: Remove `ReplaceUrbanPhotoCommand`, UrbanPhoto file picker, and UrbanPhoto replace button from `WeighingRecordEditDialog`.



---



### Requirement: EditResult carries replacement image data — Base64 fields for client



**Reason**: MaterialClient persists Lrp changes locally and syncs via upload; Base64 on `EditResult` is Web-only.



**Migration**: Remove `LrpReplacementBase64` and `UrbanPhotoReplacementBase64` from MaterialClient `EditResult` and ViewModel replacement properties used for server approval.



---



### Requirement: Client passes replacement images to server approval call — Approve API path



**Reason**: Client approval uses local attachments + `ReceiveAsync`, not `ApproveAsync` or `ApproveWeighingRecordAsync`.



**Migration**: Remove `await api.ApproveWeighingRecordAsync(...)` and any `ApproveAsync` call from `UrbanAttendedWeighingViewModel`; remove Approve Refit method from `IUrbanManagementApi`.



## ADDED Requirements



### Requirement: Service method to create Lrp from UrbanPhoto on client



MaterialClient.Urban SHALL provide a Service-layer method (e.g. on `IAttachmentService`) that creates a local Lrp attachment from an existing UrbanPhoto attachment for a given weighing record.



#### Scenario: Create Lrp from UrbanPhoto succeeds



- **WHEN** `CreateLrpFromUrbanPhotoAsync` (or equivalent) is called for a record that has UrbanPhoto but no Lrp

- **THEN** the Service SHALL read the UrbanPhoto file from normalized `LocalPath`

- **AND** SHALL persist a new image file under Lrp storage conventions

- **AND** SHALL insert `AttachmentFile` with `AttachType.Lrp` and link via `WeighingRecordAttachment`

- **AND** SHALL return the new Lrp local path or attachment id for UI preview



#### Scenario: UrbanPhoto file missing



- **WHEN** UrbanPhoto attachment row exists but the file is missing on disk

- **THEN** the Service SHALL fail with a clear error

- **AND** SHALL NOT create a partial Lrp attachment



#### Scenario: Load uses service layer only



- **WHEN** the dialog ViewModel creates Lrp from UrbanPhoto

- **THEN** it MUST call the approved Service method

- **AND** MUST NOT inject or call `IRepository<AttachmentFile>` directly


