## MODIFIED Requirements

### Requirement: Pending record selection from UrbanWeighingRecord

The system SHALL query `UrbanWeighingRecord` records where `SyncType` is not equal to `SyncStatus.Success`, `RetryCount` is less than 10 (max retries), `IsAnomaly` is false, and the record's associated `GovProject` (matched via `ProId`) has sync enabled (`EnableSync == true` until renamed in a later change).

#### Scenario: Selecting records for sync

- **WHEN** the worker executes and there are UrbanWeighingRecord records with `SyncType = Pending` and `RetryCount = 2` and `IsAnomaly = false` associated with a project where sync is enabled
- **THEN** these records SHALL be included in the sync batch

#### Scenario: Excluding synced records

- **WHEN** the worker executes and a record has `SyncType = Success`
- **THEN** this record SHALL NOT be included in the sync batch

#### Scenario: Excluding exhausted retries

- **WHEN** a record has `RetryCount >= 10`
- **THEN** this record SHALL NOT be included in the sync batch regardless of SyncType

#### Scenario: Excluding anomalous records

- **WHEN** a record has `IsAnomaly = true`
- **THEN** this record SHALL NOT be included in the sync batch

#### Scenario: Excluding disabled projects

- **WHEN** a record is associated with a project where sync is not enabled
- **THEN** this record SHALL NOT be included in the sync batch

### Requirement: HTTP forwarding with Refit and Polly

The system SHALL use a Refit-based `IGovSyncHttpClient` to POST typed government sync payloads to the configurable `GovAddress` endpoint. The HTTP client SHALL use Polly retry policy with 3 attempts and exponential backoff for transient failures. Business success SHALL be determined from the government API response body field `code` equal to `200`. The system MUST NOT treat sync as successful based solely on a `success` boolean property when the government response does not include that field.

#### Scenario: Successful forward

- **WHEN** the government API responds with HTTP success and response body `code` equal to `200`
- **THEN** the system SHALL update the record's `SyncType` to `SyncStatus.Success` and set `SyncTime` to the current time

#### Scenario: Forward failure with retry

- **WHEN** the government API responds with a response body where `code` is not equal to `200`
- **THEN** the system SHALL update `SyncType` to `SyncStatus.Failed`, increment `RetryCount` by 1, and log the failure with `code` and `msg`

#### Scenario: Exhausted retries

- **WHEN** `RetryCount` reaches 10
- **THEN** the system SHALL mark the record as permanently failed and stop retrying

#### Scenario: Missing image files

- **WHEN** the background worker cannot find an image file referenced by an attachment record
- **THEN** the system SHALL set `RetryCount` to 10 (stop retrying) and log the error

#### Scenario: Government response without success field

- **WHEN** the government API returns `{ "code": 200, "msg": "操作成功", "data": null }` without a `success` field
- **THEN** the system SHALL treat the forward as successful
- **AND** SHALL update `SyncType` to `SyncStatus.Success`

### Requirement: Re-approved records re-enter government sync queue

When an administrator approves a weighing record on UrbanManagement and the service resets `SyncType` to pending, the existing `GovSyncBackgroundWorker` SHALL treat the record as eligible for government sync again when other selection criteria are met.

#### Scenario: Pending sync after web approval

- **WHEN** a record had `SyncType = Success` or `SyncStatus.Failed` before approval
- **AND** approval sets `SyncType = Pending` and `IsAnomaly = false`
- **AND** the associated `GovProject` has sync enabled
- **THEN** `GovSyncBackgroundWorker` SHALL include the record in a subsequent sync batch

#### Scenario: Anomalous record excluded after approval

- **WHEN** approval recalculates `IsAnomaly = true`
- **THEN** `GovSyncBackgroundWorker` SHALL NOT include the record in the sync batch
- **AND** this SHALL match existing anomalous-record exclusion behavior

### Requirement: Gov worker re-queue after reset

Reset sync MUST NOT require changes to Gov sync worker selection rules beyond using `SyncStatus` enum. After reset, checkpoint rows MUST become eligible for `GovCheckpointSyncManager` pending selection and finished-product rows for `GovProductSyncManager`, using `SyncType != SyncStatus.Success`.

#### Scenario: Checkpoint re-queued

- **WHEN** a checkpoint row is reset from failed to pending
- **THEN** the next Gov checkpoint sync cycle MAY pick up that row when `SyncType` is not `Success`
