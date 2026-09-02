## MODIFIED Requirements

### Requirement: UrbanServerUploadService reads LicenseInfo for project fields

`UrbanServerUploadService.SubmitRecordAsync()` SHALL read the current `LicenseInfo` and populate required `ProId`, `ProName`, and `BuildLicenseNo`, and SHALL set `SiteType` to an `UrbanSiteType` value (from Scale LPR snapshot or `Construction` default). The submit DTO MUST NOT include `FdBuildLicenseNo`. `ProId` MUST be a non-empty `Guid` from `LicenseInfo.ProjectId`.

#### Scenario: LicenseInfo exists with project fields

- **WHEN** `SubmitRecordAsync` is called and `LicenseInfo` exists with a non-empty `ProjectId`, `ProName`, and `AccessCode`
- **THEN** `UrbanWeighingRecordSubmitDto.ProId` SHALL be set to `LicenseInfo.ProjectId`
- **AND** `UrbanWeighingRecordSubmitDto.SiteType` SHALL be a defined `UrbanSiteType` value
- **AND** the serialized JSON MUST NOT include `fdBuildLicenseNo`

#### Scenario: LicenseInfo does not exist

- **WHEN** `SubmitRecordAsync` is called and no `LicenseInfo` exists
- **THEN** the upload SHALL NOT proceed with a weighing submit
- **AND** SHALL log a warning that license info is not available
