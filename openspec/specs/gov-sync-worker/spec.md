# Government Sync Worker

## Purpose

Provides background synchronization capabilities for forwarding urban weighing records to government platforms automatically with retry logic and comprehensive logging. (TBD: expand with architectural overview)

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
For each pending UrbanWeighingRecord, the system SHALL create a `GovSyncData` entity mapping fields: `PlateNumber→CarNo`, `VehicleColor→CarColor`, `PlateColor→CarNoColor`, `VehicleType→CarType`, `WeighingTime→SnapTime` (formatted as `yyyy-MM-dd HH:mm:ss`), `DeviceId→DeviceId`, `BuildLicenseNo→BuildLicenseNo`, `SiteType→SiteType`, `TotalWeight→GoodsWeight` (string). The payload SHALL include `carType` determined by `TotalWeight > 4500 → "大车" else "小车"`, `snapImages` loaded from attachment files as Base64 array, and `inOutType=0`, `tareWeight=0` as defaults.

#### Scenario: Heavy vehicle classification
- **WHEN** a record has `TotalWeight` value greater than 4500
- **THEN** the payload `carType` SHALL be set to "大车"

#### Scenario: Light vehicle classification
- **WHEN** a record has `TotalWeight` value of 4500 or less
- **THEN** the payload `carType` SHALL be set to "小车"

### Requirement: HTTP forwarding with Refit and Polly
The system SHALL use a Refit-based `IGovSyncHttpClient` to POST payloads to the configurable `GovAddress` endpoint. The HTTP client SHALL use Polly retry policy with 3 attempts and exponential backoff for transient failures.

#### Scenario: Successful forward
- **WHEN** the government API responds with success
- **THEN** the system SHALL update the record's `SyncType` to 1 and set `SyncTime` to the current time

#### Scenario: Forward failure with retry
- **WHEN** the government API responds with a failure
- **THEN** the system SHALL update `SyncType` to 2, increment `RetryCount` by 1, and log the failure

#### Scenario: Exhausted retries
- **WHEN** `RetryCount` reaches 10
- **THEN** the system SHALL mark the record as permanently failed and stop retrying

#### Scenario: Missing image files
- **WHEN** the background worker cannot find an image file referenced by an attachment record
- **THEN** the system SHALL set `RetryCount` to 10 (stop retrying) and log the error

### Requirement: Sync logging
The system SHALL create a `GovLog` record for each sync attempt, containing: `SyncId` (the UrbanWeighingRecord Id cast to int? or stored as string), `SyncNumber` (current attempt count), `SyncTime` (current time), `SyncSource` (JSON payload sent), `SyncResult` (success/failure), `SyncCode` (response code), and `SyncMsg` (response message).

#### Scenario: Logging a successful sync
- **WHEN** a record is successfully forwarded to the government API
- **THEN** a `GovLog` entry SHALL be created with the response details and a success indicator

#### Scenario: Logging a failed sync
- **WHEN** a forward attempt fails
- **THEN** a `GovLog` entry SHALL be created with the failure reason and response code

### Requirement: Configurable government endpoint
The government API address SHALL be read from `StorageOptions.GovAddress` configuration. The default value SHALL be empty (not a hardcoded URL), requiring explicit configuration in production.

#### Scenario: Custom government endpoint
- **WHEN** `appsettings.json` contains `"GovAddress": "http://custom.gov.api/endpoint"`
- **THEN** the sync worker SHALL POST to that URL
