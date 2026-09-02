## MODIFIED Requirements

### Requirement: Urban weighing and passage upload include required ProId

MaterialClient.Urban upload DTOs for weighing and passage (`UrbanWeighingRecordSubmitDto`, `UrbanPassageSubmitDto`) SHALL expose `ProId` as **non-nullable `Guid`**. Upload services MUST populate `ProId` from `LicenseInfo.ProjectId` and MUST NOT submit when `ProjectId` is `Guid.Empty`.

#### Scenario: Weighing upload includes ProId from license

- **WHEN** `UrbanServerUploadService` builds a weighing submit payload under valid license
- **THEN** `ProId` SHALL equal `LicenseInfo.ProjectId`
- **AND** serialized JSON SHALL include `proId` as a Guid value

#### Scenario: Passage upload includes ProId from license

- **WHEN** `UrbanPassageUploadService` builds a passage submit payload under valid license
- **THEN** `ProId` SHALL equal `LicenseInfo.ProjectId`
- **AND** MUST NOT send null or empty Guid
