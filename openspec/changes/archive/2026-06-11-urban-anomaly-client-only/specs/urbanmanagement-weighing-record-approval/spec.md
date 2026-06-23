## MODIFIED Requirements

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

### Requirement: Approval updates record and recalculates anomaly

On successful approval, the system SHALL update the server `UrbanWeighingRecord`, clear the anomaly flag when plate and weight validation pass, and reset government sync state to pending. The system MUST NOT recalculate `IsAnomaly` using threshold-based `IUrbanAnomalyDetector`.

#### Scenario: Fields updated in database

- **WHEN** approval succeeds for record `id`
- **THEN** `PlateNumber` and `TotalWeight` on `UrbanWeighingRecord` SHALL be updated to the submitted values

#### Scenario: Valid approval clears anomaly for sync

- **WHEN** approval persists the updated record
- **AND** the submitted plate number passes `PlateNumberValidator.IsValidChinesePlateNumber`
- **AND** the submitted `TotalWeight` is a valid positive number
- **THEN** `IsAnomaly` SHALL be set to `false`
- **AND** the system MUST NOT invoke threshold-based anomaly detection on the server

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

## ADDED Requirements

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
