# UrbanManagement Weighing Record Approval

## Purpose

Web-based approval workflow for UrbanManagement weighing records: list action for anomalous rows only, approval dialog, plate/weight validation, anomaly clearance on approval, confirmation before persist, and sync state reset.
## Requirements
### Requirement: Weighing record list exposes approval action

The UrbanManagement weighing record **approval page** (`/weighing-approval`) SHALL provide an approval action only for rows where `IsAnomaly == true`. The weighing record management page (`/weighing`) SHALL NOT provide an approval action.

#### Scenario: Approval button on approval page

- **WHEN** the administrator views the approval page LayUI table
- **THEN** each row with `IsAnomaly == true` SHALL include an operation control labeled「审批」
- **AND** activating the control SHALL open an approval dialog for that row's server record `Id`

#### Scenario: Normal row has no approval action

- **WHEN** a row has `IsAnomaly == false`
- **THEN** the row MUST NOT expose an enabled「审批」control
- **AND** the operator MUST NOT be able to open the approval dialog for that row from the list

#### Scenario: No approval button on weighing record page

- **WHEN** the administrator views the weighing record management page (`/weighing`)
- **THEN** no approval action SHALL be present on any row
- **AND** the "操作" column SHALL NOT appear in the table

### Requirement: Approval dialog matches client edit fields

The approval UI SHALL allow editing `PlateNumber` and `TotalWeight` and SHALL pre-populate current values from the selected `UrbanWeighingRecord`.

#### Scenario: Dialog opens with current values

- **WHEN** the approval dialog opens for a record
- **THEN** the plate number field SHALL show the record's current `PlateNumber`
- **AND** the total weight field SHALL show the record's current `TotalWeight` formatted for editing (e.g. two decimal places)

#### Scenario: Operator cancels

- **WHEN** the operator closes the dialog without confirming
- **THEN** no update SHALL be persisted
- **AND** the list SHALL remain unchanged

### Requirement: Approval validates plate number like the client

Before persisting approval, the system SHALL validate the plate number using the same rules as MaterialClient.Urban (`PlateNumberValidator.IsValidChinesePlateNumber` semantics).

#### Scenario: Empty plate rejected

- **WHEN** the operator submits approval with an empty or whitespace plate number
- **THEN** the system SHALL reject the submission with a validation error
- **AND** the record SHALL NOT be updated

#### Scenario: Invalid Chinese plate format rejected

- **WHEN** the operator submits a non-empty plate number that fails Chinese plate format validation
- **THEN** the system SHALL reject the submission with a message equivalent to「车牌号不符合规范请修改」
- **AND** the record SHALL NOT be updated

#### Scenario: Valid plate accepted

- **WHEN** the operator submits a plate number that passes validation and a positive `TotalWeight`
- **THEN** the system SHALL proceed with the approval update

### Requirement: Approval updates record and recalculates anomaly
On successful approval, the system SHALL update the server `UrbanWeighingRecord`, clear the anomaly flag when plate and weight validation pass, and reset government sync state to pending. The system MUST NOT recalculate `IsAnomaly` using threshold-based `IUrbanAnomalyDetector`. Edit history SHALL be recorded in entity `ExtraProperties` under the key `"EditHistory"`.

#### Scenario: Fields updated in database
- **WHEN** approval succeeds for record `id`
- **THEN** `PlateNumber` and `TotalWeight` on `UrbanWeighingRecord` SHALL be updated to the submitted values

#### Scenario: Valid approval clears anomaly for sync
- **WHEN** approval persists the updated record
- **AND** the submitted plate number passes `PlateNumberValidator.IsValidChinesePlateNumber`
- **AND** the submitted `TotalWeight` is a valid positive number
- **THEN** `IsAnomaly` SHALL be set to `false`
- **AND** the system MUST NOT invoke threshold-based anomaly detection on the server

#### Scenario: Edit history recorded as full snapshot in ExtraProperties
- **WHEN** approval persists an updated record
- **THEN** the system SHALL read existing edit history from `record.ExtraProperties["EditHistory"]`
- **AND** SHALL create a new snapshot `EditEntry` containing the post-approval state: `ChangedAt` (UTC timestamp), `PlateNumber` (approved value), `TotalWeight` (approved value), `AnomalyReason` (empty string, since anomaly is cleared)
- **AND** SHALL append this snapshot to the existing history array
- **AND** SHALL serialize the updated list back to `record.ExtraProperties["EditHistory"]`
- **AND** the system MUST NOT write edit history to a dedicated `EditHistoryJson` property
- **AND** each entry in the history array MUST be a complete snapshot (not per-field deltas)

#### Scenario: Approved record cannot be approved again
- **WHEN** a record has `IsAnomaly == false` after a successful approval
- **THEN** subsequent list render MUST NOT offer an enabled approval action for that row
- **AND** `ApproveAsync` MUST reject a repeat approval attempt with a clear business error

#### Scenario: Sync state reset to pending
- **WHEN** approval succeeds
- **THEN** `SyncType` SHALL be set to `0` (pending / not successfully synced)
- **AND** `RetryCount` SHALL be reset to `0` so `GovSyncBackgroundWorker` may retry government upload

#### Scenario: No immediate government HTTP from approval UI
- **WHEN** approval completes successfully in the Web UI
- **THEN** the system SHALL NOT invoke government platform HTTP from the approval request path
- **AND** resync SHALL rely on `GovSyncBackgroundWorker` for eligible records (`IsAnomaly == false`, project enabled, etc.)

### Requirement: Approval does not modify attachments

The approval workflow SHALL accept optional image replacement data for Lrp and UrbanPhoto attachments. When replacement data is provided, the system SHALL replace the corresponding attachments as part of the approval transaction. When no replacement data is provided, existing attachments SHALL remain unchanged. Approval SHALL only accept `PlateNumber`, `TotalWeight`, and optional replacement image changes.

#### Scenario: Approve request includes replacement image

- **WHEN** the administrator submits approval with `LrpReplacementBase64` or `UrbanPhotoReplacementBase64` non-null and non-empty
- **THEN** the API SHALL accept the image payload
- **AND** SHALL replace the corresponding `AttachmentFile` and `UrbanWeighingRecordAttachment` rows as part of the approval transaction
- **AND** old attachment files on disk SHALL be deleted

#### Scenario: Approve request excludes replacement image

- **WHEN** the administrator submits approval without any replacement image data
- **THEN** existing `UrbanWeighingRecordAttachment` rows SHALL remain unchanged
- **AND** existing `AttachmentFile` records SHALL remain unchanged

#### Scenario: Web approval UI does not provide image replacement controls

- **WHEN** the administrator uses the Web approval dialog (`WeighingApproval.razor`)
- **THEN** the dialog SHALL NOT provide image file upload controls for replacement
- **AND** replacement image fields SHALL NOT be populated from the Web UI

### Requirement: List refreshes after approval
The weighing record table SHALL refresh after a successful approval and display updated field values.

#### Scenario: Table reflects updated values after approval
- **WHEN** approval completes successfully
- **THEN** the weighing record table SHALL refresh
- **AND** updated `PlateNumber`, `TotalWeight`, `IsAnomaly`, and sync status columns SHALL reflect the new values

### Requirement: Approval change confirmation before persist

The Web approval workflow SHALL require a secondary confirmation after input validation passes and before calling the approval API.

#### Scenario: Confirm after valid input

- **WHEN** the operator clicks「确定」in the approval dialog
- **AND** plate number and total weight pass validation
- **THEN** the UI MUST show a confirmation prompt asking whether to submit the modification
- **AND** only after the operator confirms SHALL `ApproveAsync` be invoked

#### Scenario: Cancel confirmation aborts update

- **WHEN** the operator dismisses or cancels the confirmation prompt
- **THEN** `ApproveAsync` MUST NOT be called
- **AND** the database record MUST remain unchanged
- **AND** the approval dialog MAY remain open for further edits

### Requirement: API rejects approval for non-anomalous records

`ApproveAsync` SHALL only accept records that are currently marked anomalous.

#### Scenario: Approve anomalous record

- **WHEN** `ApproveAsync` is called for a record with `IsAnomaly == true` and valid plate/weight
- **THEN** the approval update SHALL proceed

#### Scenario: Reject approval for normal record

- **WHEN** `ApproveAsync` is called for a record with `IsAnomaly == false`
- **THEN** the system MUST return a business validation error
- **AND** MUST NOT update `PlateNumber`, `TotalWeight`, or sync fields

