## ADDED Requirements

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

### Requirement: Approval entry passes weighing record identity

`UrbanAttendedWeighingViewModel` SHALL supply the `WeighingRecordId` of the list item being approved so the dialog can load the correct attachments.

#### Scenario: Approve from list opens dialog with record id

- **WHEN** the user triggers approval for a `UrbanWeighingListItemDto` row
- **THEN** `ApproveRecordAsync` SHALL pass that row's `WeighingRecordId` to the dialog ViewModel
- **AND** the dialog SHALL load photos for that id before or when the dialog is shown
