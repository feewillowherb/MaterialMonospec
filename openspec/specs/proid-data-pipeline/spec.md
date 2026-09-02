# ProId Data Pipeline Specification

## Purpose

定义称重记录上传流程中的项目数据（ProId、ProName、BuildLicenseNo、FdBuildLicenseNo）从 LicenseInfo 到 DTO 再到服务端的完整数据流，确保项目关联信息正确传递和持久化。
## Requirements

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

### Requirement: DeviceStatusHub remains unassociated with ProId

`DeviceStatusMessage` SHALL NOT include ProId or any project-related fields. Device status is tracked per ClientId, which represents a physical machine. Project association is resolved separately through ClientId → LicenseInfo → ProId lookup when needed.

#### Scenario: DeviceStatusMessage structure unchanged

- **WHEN** `DeviceStatusHub.UploadStatus()` receives a message
- **THEN** the message SHALL only contain ClientId, DeviceType, Status, Timestamp, AdditionalData
- **AND** SHALL NOT require ProId for processing or broadcasting

#### Scenario: Project association available via indirect lookup

- **WHEN** a consumer needs to know which project a device belongs to
- **THEN** the consumer SHALL look up `LicenseInfo` by the device's ClientId (machine code)
- **AND** SHALL read `ProjectId` (ProId) from the LicenseInfo record
- **AND** `DeviceStatusMessage` SHALL NOT be modified

### Requirement: GovProject excludes FdBuildLicenseNo from license pipeline
The proid-data-pipeline capability SHALL treat `BuildLicenseNo` as the sole persisted project-level access code on `GovProject`, `LicenseInfo`, JWT claims, and weighing submit DTOs. No entity in the weighing upload or project resolution pipeline SHALL persist or require `FdBuildLicenseNo`.

#### Scenario: Pipeline uses BuildLicenseNo only
- **WHEN** MaterialClient uploads a weighing record or UrbanManagement resolves a project for sync
- **THEN** the effective access code SHALL come from `BuildLicenseNo` / `buildLicenseNo`
- **AND** MUST NOT depend on a persisted `FdBuildLicenseNo` on any entity in the pipeline
