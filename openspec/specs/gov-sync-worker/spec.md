# Government Sync Worker

## Purpose

Provides background synchronization capabilities for forwarding urban weighing records to government platforms automatically with retry logic and logging via Serilog. (TBD: expand with architectural overview)
## Requirements
### Requirement: Periodic background sync execution
The system SHALL run a background worker based on ABP's `AsyncPeriodicBackgroundWorkerBase` that executes every 5 seconds to forward unsynced records to the government platform API.

#### Scenario: Worker starts on application startup
- **WHEN** the UrbanManagement application starts
- **THEN** the `GovSyncBackgroundWorker` SHALL begin executing automatically with a 5-second period

#### Scenario: Worker respects cancellation
- **WHEN** the application is shutting down
- **THEN** the background worker SHALL complete its current iteration and stop gracefully

### Requirement: Pending record selection from UrbanWeighingRecord
The system SHALL query `UrbanWeighingRecord` records where `SyncType` is not equal to 1 (success), `RetryCount` is less than 10 (max retries), `IsAnomaly` is false, and the record's associated `GovProject` (matched via `ProId`) has `SyncStatus == true`.

#### Scenario: Selecting records for sync
- **WHEN** the worker executes and there are UrbanWeighingRecord records with `SyncType=0` and `RetryCount=2` and `IsAnomaly=false` associated with a project where `SyncStatus=true`
- **THEN** these records SHALL be included in the sync batch

#### Scenario: Excluding synced records
- **WHEN** the worker executes and a record has `SyncType=1`
- **THEN** this record SHALL NOT be included in the sync batch

#### Scenario: Excluding exhausted retries
- **WHEN** a record has `RetryCount >= 10`
- **THEN** this record SHALL NOT be included in the sync batch regardless of SyncType

#### Scenario: Excluding anomalous records
- **WHEN** a record has `IsAnomaly = true`
- **THEN** this record SHALL NOT be included in the sync batch

#### Scenario: Excluding disabled projects
- **WHEN** a record is associated with a project where `SyncStatus != true`
- **THEN** this record SHALL NOT be included in the sync batch

### Requirement: Government API payload assembly via GovSyncData

For each pending UrbanWeighingRecord, the system SHALL assemble an outbound government API payload with field mapping: `PlateNumber→carNo`, `VehicleColor→carColor`, `PlateColor→carNoColor`, `WeighingTime→snapTime` (formatted as `yyyy-MM-dd HH:mm:ss`), `DeviceId→deviceID`, `BuildLicenseNo→buildLicenseNo`, `SiteType→siteType`, `TotalWeight→grossWeight` (numeric kg) and `TotalWeight→goodsWeight` (string kg). The payload SHALL set `carType` to `"大车"` when `TotalWeight > 4500` kg, otherwise `"小车"`. The payload SHALL set `snapImages` to a JSON array of Base64 strings loaded from attachment files via `IFileService.ReadAttachmentFilesAsync`; when no attachments exist, `snapImages` MUST be an empty JSON array `[]`, not a string. Defaults SHALL be `inOutType=0`, `tareWeight=0`, `equipmentNumber=""`, `equipmentType=""`.

#### Scenario: Heavy vehicle classification

- **WHEN** a record has `TotalWeight` value greater than 4500
- **THEN** the payload `carType` SHALL be set to `"大车"`

#### Scenario: Light vehicle classification

- **WHEN** a record has `TotalWeight` value of 4500 or less
- **THEN** the payload `carType` SHALL be set to `"小车"`

#### Scenario: Empty snapImages as array

- **WHEN** a record has no readable attachment files
- **THEN** the outbound payload `snapImages` SHALL be a JSON array with zero elements
- **AND** the payload MUST NOT send `snapImages` as an empty string

#### Scenario: snapImages with attachments

- **WHEN** a record has attachment files readable from storage
- **THEN** the outbound payload `snapImages` SHALL be a JSON array of Base64-encoded image strings

### Requirement: HTTP forwarding with Refit and Polly

The system SHALL use a Refit-based `IGovSyncHttpClient` to POST typed government sync payloads to the configurable `GovAddress` endpoint. The HTTP client SHALL use Polly retry policy with 3 attempts and exponential backoff for transient failures. Business success SHALL be determined from the government API response body field `code` equal to `200`. The system MUST NOT treat sync as successful based solely on a `success` boolean property when the government response does not include that field.

#### Scenario: Successful forward

- **WHEN** the government API responds with HTTP success and response body `code` equal to `200`
- **THEN** the system SHALL update the record's `SyncType` to 1 and set `SyncTime` to the current time

#### Scenario: Forward failure with retry

- **WHEN** the government API responds with a response body where `code` is not equal to `200`
- **THEN** the system SHALL update `SyncType` to 2, increment `RetryCount` by 1, and log the failure with `code` and `msg`

#### Scenario: Exhausted retries

- **WHEN** `RetryCount` reaches 10
- **THEN** the system SHALL mark the record as permanently failed and stop retrying

#### Scenario: Missing image files

- **WHEN** the background worker cannot find an image file referenced by an attachment record
- **THEN** the system SHALL set `RetryCount` to 10 (stop retrying) and log the error

#### Scenario: Government response without success field

- **WHEN** the government API returns `{ "code": 200, "msg": "操作成功", "data": null }` without a `success` field
- **THEN** the system SHALL treat the forward as successful
- **AND** SHALL update `SyncType` to 1

### Requirement: Configurable government endpoint
The government API address SHALL be read from `StorageOptions.GovAddress` configuration. The default value SHALL be empty (not a hardcoded URL), requiring explicit configuration in production.

#### Scenario: Custom government endpoint
- **WHEN** `appsettings.json` contains `"GovAddress": "http://custom.gov.api/endpoint"`
- **THEN** the sync worker SHALL POST to that URL

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

