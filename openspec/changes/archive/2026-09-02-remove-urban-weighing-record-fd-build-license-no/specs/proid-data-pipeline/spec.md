## MODIFIED Requirements

### Requirement: UrbanServerUploadService reads LicenseInfo for project fields

`UrbanServerUploadService.SubmitRecordAsync()` SHALL read the current `LicenseInfo` from `ILicenseService.GetCurrentLicenseAsync()` and populate ProId, ProName, and BuildLicenseNo in the `UrbanWeighingRecordSubmitDto` instead of hardcoding null. The submit DTO MUST NOT include `FdBuildLicenseNo`.

#### Scenario: LicenseInfo exists with project fields

- **WHEN** `SubmitRecordAsync` is called and `LicenseInfo` exists with ProId, ProName, and AccessCode (mapped to BuildLicenseNo)
- **THEN** `UrbanWeighingRecordSubmitDto.ProId` SHALL be set to `LicenseInfo.ProjectId`
- **AND** `UrbanWeighingRecordSubmitDto.ProName` SHALL be set to `LicenseInfo.ProName`
- **AND** `UrbanWeighingRecordSubmitDto.BuildLicenseNo` SHALL be set to `LicenseInfo.AccessCode`
- **AND** the serialized JSON MUST NOT include `fdBuildLicenseNo`

#### Scenario: LicenseInfo does not exist

- **WHEN** `SubmitRecordAsync` is called and no `LicenseInfo` exists
- **THEN** ProId, ProName, and BuildLicenseNo in the DTO SHALL remain null
- **AND** SHALL log a warning that license info is not available

#### Scenario: LicenseInfo exists but project fields are null

- **WHEN** `SubmitRecordAsync` is called and `LicenseInfo` exists but ProName or AccessCode are null
- **THEN** the DTO fields SHALL be set to null (matching LicenseInfo values)
- **AND** SHALL log a debug message that some project fields are empty

## REMOVED Requirements

### Requirement: UrbanWeighingRecordSubmitDto includes FdBuildLicenseNo

**Reason**: 称重记录上云不再传递对接码快照；项目级对接码由 `GovProject.FdBuildLicenseNo` 与授权 JWT 维护。

**Migration**: 客户端与 Receive API 删除 `fdBuildLicenseNo`；需要对接码时通过 `ProId` 查询 `GovProject`。

### Requirement: UrbanWeighingRecord server entity includes FdBuildLicenseNo

**Reason**: 字段从未被读取或用于 Gov 出站；与 `BuildLicenseNo`（接入码）职责重复。

**Migration**: EF migration 删除 `UrbanWeighingRecords.FdBuildLicenseNo` 列；Receive DTO 不再接受该字段。
