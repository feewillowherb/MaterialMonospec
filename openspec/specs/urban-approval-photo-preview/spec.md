# urban-approval-photo-preview Specification

## Purpose
TBD - created by archiving change add-urban-approval-photo-preview. Update Purpose after archive.
## Requirements
### Requirement: Approval dialog loads LRP and UrbanPhoto attachments

When the weighing record approval dialog opens, the system SHALL load attachment file paths for the record being approved using `IAttachmentService`, keyed by `WeighingRecordId`.

#### Scenario: Both attachment types exist

- **WHEN** the approval dialog is opened for a record that has `AttachmentFile` rows with `AttachType.Lrp` and `AttachType.UrbanPhoto` and non-empty `LocalPath`
- **THEN** the dialog ViewModel SHALL expose `LprPhotoPath` and `CameraPhotoPath` (or equivalent properties) with those resolved paths
- **AND** the dialog UI SHALL display thumbnail previews for both images

#### Scenario: Only LRP exists

- **WHEN** the approval dialog is opened and only `AttachType.Lrp` has a non-empty `LocalPath`
- **THEN** `LprPhotoPath` SHALL be set and the LRP thumbnail SHALL show the image
- **AND** the UrbanPhoto area SHALL show the default placeholder (via `CarNullOrEmptyImageConverter` or equivalent)
- **AND** `CameraPhotoPath` SHALL be null or empty

#### Scenario: Only UrbanPhoto exists

- **WHEN** the approval dialog is opened and only `AttachType.UrbanPhoto` has a non-empty `LocalPath`
- **THEN** `CameraPhotoPath` SHALL be set and the UrbanPhoto thumbnail SHALL show the image
- **AND** the LRP area SHALL show the default placeholder
- **AND** `LprPhotoPath` SHALL be null or empty

#### Scenario: No attachments

- **WHEN** the approval dialog is opened and no LRP or UrbanPhoto attachments exist for the record
- **THEN** both preview areas SHALL show placeholders
- **AND** the user SHALL still be able to edit plate number and weight and confirm or cancel

#### Scenario: Load uses service layer only

- **WHEN** the dialog ViewModel loads attachment paths
- **THEN** it MUST call `IAttachmentService` (or another approved Service)
- **AND** it MUST NOT inject or call `IRepository<AttachmentFile>` directly

---

### Requirement: Approval dialog photo preview is clickable

The approval dialog SHALL allow the operator to open full-screen image viewing for LRP and UrbanPhoto previews, consistent with the Urban main window sidebar behavior.

#### Scenario: Click LRP thumbnail opens viewer

- **WHEN** the user clicks the LRP preview in the approval dialog
- **AND** `LprPhotoPath` is not null or empty
- **THEN** the system SHALL open `ImageViewerWindow` from `MaterialClient.UI`
- **AND** the viewer title SHALL be「车牌识别抓拍」
- **AND** the image SHALL load from `LprPhotoPath`

#### Scenario: Click UrbanPhoto thumbnail opens viewer

- **WHEN** the user clicks the UrbanPhoto (camera capture) preview in the approval dialog
- **AND** `CameraPhotoPath` is not null or empty
- **THEN** the system SHALL open `ImageViewerWindow`
- **AND** the viewer title SHALL be「摄像头抓拍」
- **AND** the image SHALL load from `CameraPhotoPath`

#### Scenario: Click preview with empty path

- **WHEN** the user clicks a preview area and the corresponding path is null or empty
- **THEN** the system SHALL NOT open `ImageViewerWindow`
- **AND** the system SHALL NOT throw an unhandled exception

#### Scenario: Viewer open failure is logged

- **WHEN** opening the image viewer fails (e.g. file missing)
- **THEN** the application SHALL remain stable
- **AND** the error SHALL be logged

---

### Requirement: Approval dialog photo replace button overlay

The `WeighingRecordEditDialog` SHALL provide a replace button on each photo preview section (Lrp and UrbanPhoto), allowing the operator to initiate image replacement.

#### Scenario: Lrp section shows replace button

- **WHEN** the approval edit dialog renders the Lrp photo preview section
- **THEN** a "替换" button SHALL be visible below or overlaid on the Lrp preview area

#### Scenario: UrbanPhoto section shows replace button

- **WHEN** the approval edit dialog renders the UrbanPhoto photo preview section
- **THEN** a "替换" button SHALL be visible below or overlaid on the UrbanPhoto preview area

#### Scenario: Replace button triggers file picker

- **WHEN** the operator clicks the "替换" button on either photo section
- **THEN** the system SHALL trigger the corresponding replace command (`ReplaceLrpCommand` or `ReplaceUrbanPhotoCommand`)
- **AND** a native file picker SHALL open

---

### Requirement: Lrp empty shows capture anomaly warning in client approval dialog

The `WeighingRecordEditDialog` SHALL display a "抓拍异常" warning indicator when the Lrp photo attachment is absent.

#### Scenario: Lrp empty with anomaly warning

- **WHEN** the approval dialog loads photos and `LprPhotoPath` is null or empty
- **THEN** the Lrp preview area SHALL display the default placeholder image
- **AND** SHALL display "抓拍异常" warning text in a distinct style (e.g. yellow/orange foreground)

#### Scenario: Lrp present without anomaly warning

- **WHEN** the approval dialog loads photos and `LprPhotoPath` is not null or empty
- **THEN** the "抓拍异常" warning text SHALL NOT be displayed

---

### Requirement: Approval entry passes weighing record identity

`UrbanAttendedWeighingViewModel` SHALL supply the `WeighingRecordId` of the list item being approved so the dialog can load the correct attachments.

#### Scenario: Approve from list opens dialog with record id

- **WHEN** the user triggers approval for a `UrbanWeighingListItemDto` row
- **THEN** `ApproveRecordAsync` SHALL pass that row's `WeighingRecordId` to the dialog ViewModel
- **AND** the dialog SHALL load photos for that id before or when the dialog is shown

