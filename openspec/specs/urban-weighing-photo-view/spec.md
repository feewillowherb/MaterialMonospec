# urban-weighing-photo-view Specification

## Purpose
TBD - created by archiving change add-weighing-photo-view-align-attachtype. Update Purpose after archive.
## Requirements
### Requirement: Weighing record list photo view action

`WeighingRecord.razor` SHALL provide a read-only「查看照片」action on each table row that opens a photo dialog for that record.

#### Scenario: Open photo dialog from weighing record list

- **WHEN** the administrator clicks「查看照片」on a row in `WeighingRecord.razor`
- **THEN** the system SHALL open a modal dialog titled with the record plate number (or equivalent identifier)
- **AND** SHALL call `IUrbanWeighingRecordAppService.GetApprovalAttachmentsAsync(recordId)` to load images
- **AND** SHALL display Lrp and UrbanPhoto preview slots labeled「车牌识别」and「现场抓拍」

#### Scenario: Photo dialog shows placeholders when images missing

- **WHEN** the photo dialog opens and one or both attachment types are unavailable
- **THEN** the missing slot(s) SHALL show an empty-state placeholder
- **AND** the dialog SHALL remain usable (close button works, no unhandled exception)

#### Scenario: Photo dialog is read-only

- **WHEN** the photo dialog is open
- **THEN** the user SHALL NOT be able to edit, upload, or delete attachments from the Web UI

### Requirement: Approval page photo view action

`WeighingApproval.razor` SHALL provide a read-only「查看照片」action on each table row, independent of the approval workflow.

#### Scenario: Open photo dialog from approval page list

- **WHEN** the administrator clicks「查看照片」on a row in `WeighingApproval.razor`
- **THEN** the system SHALL open the same read-only photo dialog behavior as `WeighingRecord.razor`
- **AND** SHALL load images via `GetApprovalAttachmentsAsync`

#### Scenario: Photo view available for non-anomalous rows

- **WHEN** the approval page filter shows non-anomalous records
- **THEN**「查看照片」SHALL still be available on those rows
- **AND** SHALL NOT require opening the approval modal

### Requirement: Photo display limited to Lrp and UrbanPhoto

The Web photo view SHALL only display images classified as `AttachType.Lrp` (5) and `AttachType.UrbanPhoto` (6). Other attach types MUST NOT appear in the photo dialog.

#### Scenario: Only Lrp and UrbanPhoto slots rendered

- **WHEN** the photo dialog renders
- **THEN** exactly two image areas SHALL be shown (Lrp and UrbanPhoto)
- **AND** attachments of other types linked to the record SHALL be ignored for display

#### Scenario: First image per type

- **WHEN** a record has multiple attachments of the same `AttachType`
- **THEN** the dialog SHALL display the first available image for that type
- **AND** additional images of the same type SHALL NOT be shown in this dialog

