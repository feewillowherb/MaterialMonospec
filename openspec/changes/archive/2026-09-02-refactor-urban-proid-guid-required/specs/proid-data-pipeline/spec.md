## MODIFIED Requirements

### Requirement: UrbanServerUploadService reads LicenseInfo for project fields

`UrbanServerUploadService.SubmitRecordAsync()` SHALL read the current `LicenseInfo` from `ILicenseService.GetCurrentLicenseAsync()` and populate **required** `ProId`, `ProName`, and `BuildLicenseNo` in the `UrbanWeighingRecordSubmitDto`. The submit DTO MUST NOT include `FdBuildLicenseNo`. `ProId` MUST be a non-empty `Guid` sourced from `LicenseInfo.ProjectId`.

#### Scenario: LicenseInfo exists with project fields

- **WHEN** `SubmitRecordAsync` is called and `LicenseInfo` exists with a non-empty `ProjectId`, `ProName`, and `AccessCode`
- **THEN** `UrbanWeighingRecordSubmitDto.ProId` SHALL be set to `LicenseInfo.ProjectId`
- **AND** `UrbanWeighingRecordSubmitDto.ProName` SHALL be set to `LicenseInfo.ProName`
- **AND** `UrbanWeighingRecordSubmitDto.BuildLicenseNo` SHALL be set to `LicenseInfo.AccessCode`
- **AND** the serialized JSON MUST NOT include `fdBuildLicenseNo`

#### Scenario: LicenseInfo does not exist

- **WHEN** `SubmitRecordAsync` is called and no `LicenseInfo` exists
- **THEN** the upload SHALL NOT proceed with a weighing submit
- **AND** SHALL log a warning that license info is not available

#### Scenario: LicenseInfo exists but ProjectId is empty

- **WHEN** `SubmitRecordAsync` is called and `LicenseInfo.ProjectId` is `Guid.Empty`
- **THEN** the upload SHALL NOT proceed
- **AND** SHALL log a warning that ProId is invalid
