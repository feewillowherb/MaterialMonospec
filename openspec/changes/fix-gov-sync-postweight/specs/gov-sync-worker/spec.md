## MODIFIED Requirements

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
