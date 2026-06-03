## ADDED Requirements

### Requirement: Weighing record list exposes approval action

The UrbanManagement weighing record list page SHALL provide an approval action for each row that opens an approval UI for that record.

#### Scenario: Approval button visible on list row

- **WHEN** the administrator views the weighing record LayUI table
- **THEN** each row SHALL include an operation control labeled「审批」
- **AND** activating the control SHALL open an approval dialog for that row's server record `Id`

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

On successful approval, the system SHALL update the server `UrbanWeighingRecord`, recalculate `IsAnomaly`, and reset government sync state to pending.

#### Scenario: Fields updated in database

- **WHEN** approval succeeds for record `id`
- **THEN** `PlateNumber` and `TotalWeight` on `UrbanWeighingRecord` SHALL be updated to the submitted values

#### Scenario: IsAnomaly recalculated

- **WHEN** approval persists the updated record
- **THEN** `IsAnomaly` SHALL be recalculated using `IUrbanAnomalyDetector` with `UrbanAnomalyDetection` configuration
- **AND** the result SHALL follow the same rules as MaterialClient `UrbanAnomalyDetector` (empty plate, upper/lower limit with deviation percentage)

#### Scenario: Sync state reset to pending

- **WHEN** approval succeeds
- **THEN** `SyncType` SHALL be set to `0` (pending / not successfully synced)
- **AND** `RetryCount` SHALL be reset to `0` so `GovSyncBackgroundWorker` may retry government upload

#### Scenario: No immediate government HTTP from approval UI

- **WHEN** approval completes successfully in the Web UI
- **THEN** the system SHALL NOT invoke government platform HTTP from the approval request path
- **AND** resync SHALL rely on `GovSyncBackgroundWorker` for eligible records (`IsAnomaly == false`, project enabled, etc.)

### Requirement: Approval does not modify attachments

The approval workflow SHALL NOT provide image or attachment editing, upload, replacement, or deletion. Approval SHALL only accept `PlateNumber` and `TotalWeight` changes.

#### Scenario: Approve request excludes attachment fields

- **WHEN** the administrator submits approval
- **THEN** the API and UI SHALL NOT accept attachment identifiers or image payloads
- **AND** existing `UrbanWeighingRecordAttachment` rows SHALL remain unchanged

### Requirement: List refreshes after approval

- **WHEN** approval completes successfully
- **THEN** the weighing record table SHALL refresh
- **AND** updated `PlateNumber`, `TotalWeight`, `IsAnomaly`, and sync status columns SHALL reflect the new values
