## ADDED Requirements

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
