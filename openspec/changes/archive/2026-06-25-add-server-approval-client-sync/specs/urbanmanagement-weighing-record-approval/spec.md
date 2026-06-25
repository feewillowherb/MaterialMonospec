## MODIFIED Requirements

### Requirement: Approval updates record and recalculates anomaly

On successful approval, the system SHALL update the server `UrbanWeighingRecord`, clear the anomaly flag when plate and weight validation pass, reset government sync state to pending, and record server approval sync metadata. The system MUST NOT recalculate `IsAnomaly` using threshold-based `IUrbanAnomalyDetector`. Edit history SHALL be recorded in entity `ExtraProperties` under the key `"EditHistory"`.

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

#### Scenario: ServerApprovedAt recorded on approval

- **WHEN** approval succeeds
- **THEN** `ServerApprovedAt` SHALL be set to the approval timestamp
- **AND** `ClientApprovalAckAt` SHALL be set to null

#### Scenario: Client sync push triggered after approval

- **WHEN** approval succeeds for a record with `ClientRecordId` and `ProId`
- **THEN** the system SHALL attempt SignalR push of server approval sync per `server-approval-client-sync`
- **AND** approval MUST succeed even if push fails
