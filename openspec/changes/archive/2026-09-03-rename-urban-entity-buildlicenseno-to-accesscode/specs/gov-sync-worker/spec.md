## MODIFIED Requirements

### Requirement: Government API payload assembly via GovSyncData

For each pending UrbanWeighingRecord, the system SHALL assemble an outbound government API payload with field mapping: `PlateNumber→carNo`, `VehicleColor→carColor`, `PlateColor→carNoColor`, `WeighingTime→snapTime` (formatted as `yyyy-MM-dd HH:mm:ss`), `DeviceId→deviceID`, **`AccessCode→buildLicenseNo`**, **`SiteType` (`UrbanSiteType`)→`siteType` (Xiaoshan wire string via weighbridge converter)**, `TotalWeight→grossWeight` (numeric kg) and `TotalWeight→goodsWeight` (string kg). The payload SHALL set `carType` to `"大车"` when `TotalWeight > 4500` kg, otherwise `"小车"`. The payload SHALL set `snapImages` to a JSON array of Base64 strings loaded from attachment files via `IFileService.ReadAttachmentFilesAsync`; when no attachments exist, `snapImages` MUST be an empty JSON array `[]`, not a string. Defaults SHALL be `inOutType=0`, `tareWeight=0`, `equipmentNumber=""`, `equipmentType=""`. The outbound JSON key MUST remain `buildLicenseNo` (MUST NOT rename the government wire field).

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

#### Scenario: Disposal maps to wire siteType 2

- **WHEN** a pending weighing record with `SiteType = Disposal` is assembled for government upload
- **THEN** the outbound payload `siteType` SHALL be the string `"2"`

#### Scenario: Construction maps to wire siteType 1

- **WHEN** a pending weighing record with `SiteType = Construction` is assembled for government upload
- **THEN** the outbound payload `siteType` SHALL be the string `"1"`

#### Scenario: AccessCode maps to wire buildLicenseNo

- **WHEN** a pending weighing record with `AccessCode` set is assembled for government upload
- **THEN** the outbound payload JSON property `buildLicenseNo` SHALL equal that `AccessCode` value
