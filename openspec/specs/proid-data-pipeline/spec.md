# ProId Data Pipeline Specification

## Purpose

定义称重记录上传流程中的项目数据（ProId、ProName、BuildLicenseNo、FdBuildLicenseNo）从 LicenseInfo 到 DTO 再到服务端的完整数据流，确保项目关联信息正确传递和持久化。

## Requirements

### Requirement: UrbanServerUploadService reads LicenseInfo for project fields

`UrbanServerUploadService.SubmitRecordAsync()` SHALL read the current `LicenseInfo` from `ILicenseService.GetCurrentLicenseAsync()` and populate ProId, ProName, BuildLicenseNo, and FdBuildLicenseNo in the `UrbanWeighingRecordSubmitDto` instead of hardcoding null.

#### Scenario: LicenseInfo exists with project fields

- **WHEN** `SubmitRecordAsync` is called and `LicenseInfo` exists with ProId, ProName, BuildLicenseNo, FdBuildLicenseNo
- **THEN** `UrbanWeighingRecordSubmitDto.ProId` SHALL be set to `LicenseInfo.ProjectId.ToString()`
- **AND** `UrbanWeighingRecordSubmitDto.ProName` SHALL be set to `LicenseInfo.ProName`
- **AND** `UrbanWeighingRecordSubmitDto.BuildLicenseNo` SHALL be set to `LicenseInfo.BuildLicenseNo`
- **AND** `UrbanWeighingRecordSubmitDto.FdBuildLicenseNo` SHALL be set to `LicenseInfo.FdBuildLicenseNo`

#### Scenario: LicenseInfo does not exist

- **WHEN** `SubmitRecordAsync` is called and no `LicenseInfo` exists
- **THEN** ProId, ProName, BuildLicenseNo, FdBuildLicenseNo in the DTO SHALL remain null
- **AND** SHALL log a warning that license info is not available

#### Scenario: LicenseInfo exists but project fields are null

- **WHEN** `SubmitRecordAsync` is called and `LicenseInfo` exists but ProName/BuildLicenseNo/FdBuildLicenseNo are null
- **THEN** the DTO fields SHALL be set to null (matching LicenseInfo values)
- **AND** SHALL log a debug message that some project fields are empty

### Requirement: UrbanWeighingRecordSubmitDto includes FdBuildLicenseNo

`UrbanWeighingRecordSubmitDto` SHALL include a `FdBuildLicenseNo` (string?) field with JSON property name `fdBuildLicenseNo`, matching the naming convention of existing fields.

#### Scenario: DTO round-trip with FdBuildLicenseNo

- **WHEN** `UrbanWeighingRecordSubmitDto` is serialized with FdBuildLicenseNo set
- **THEN** the JSON output SHALL include `"fdBuildLicenseNo": "<value>"`
- **AND** deserialization SHALL correctly map the field back

#### Scenario: FdBuildLicenseNo is null

- **WHEN** `UrbanWeighingRecordSubmitDto` is serialized with FdBuildLicenseNo = null
- **THEN** the JSON output SHALL omit the field or include `"fdBuildLicenseNo": null`

### Requirement: UrbanWeighingRecord server entity includes FdBuildLicenseNo

The `UrbanWeighingRecord` entity in UrbanManagement SHALL include a `FdBuildLicenseNo` (string?) property to store the value received from client submissions.

#### Scenario: Record creation with FdBuildLicenseNo

- **WHEN** a weighing record is submitted with `FdBuildLicenseNo` populated
- **THEN** the `UrbanWeighingRecord` SHALL persist `FdBuildLicenseNo` to the database
- **AND** an EF Core migration SHALL exist to add this column

#### Scenario: Record creation without FdBuildLicenseNo

- **WHEN** a weighing record is submitted with `FdBuildLicenseNo` = null
- **THEN** the `UrbanWeighingRecord.FdBuildLicenseNo` SHALL be null
- **AND** the record SHALL be created successfully

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
