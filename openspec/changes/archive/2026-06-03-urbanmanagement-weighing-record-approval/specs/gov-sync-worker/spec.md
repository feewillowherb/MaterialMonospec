## ADDED Requirements

### Requirement: Re-approved records re-enter government sync queue

When an administrator approves a weighing record on UrbanManagement and the service resets `SyncType` to pending, the existing `GovSyncBackgroundWorker` SHALL treat the record as eligible for government sync again when other selection criteria are met.

#### Scenario: Pending sync after web approval

- **WHEN** a record had `SyncType = 1` (success) or `SyncType = 2` (failed) before approval
- **AND** approval sets `SyncType = 0` and `IsAnomaly = false`
- **AND** the associated `GovProject` has sync enabled
- **THEN** `GovSyncBackgroundWorker` SHALL include the record in a subsequent sync batch

#### Scenario: Anomalous record excluded after approval

- **WHEN** approval recalculates `IsAnomaly = true`
- **THEN** `GovSyncBackgroundWorker` SHALL NOT include the record in the sync batch
- **AND** this SHALL match existing anomalous-record exclusion behavior
