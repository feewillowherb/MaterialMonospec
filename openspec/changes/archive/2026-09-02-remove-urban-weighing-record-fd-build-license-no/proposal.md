## Why

`UrbanWeighingRecord.FdBuildLicenseNo` 是历史从客户端授权管线沿下来的冗余快照字段：MaterialClient 上云从未赋值，服务端无读取路径，萧山 Gov 出站只用 `BuildLicenseNo`。保留该列与 Receive API 字段增加维护成本且易与 `GovProject.FdBuildLicenseNo`（项目级对接码，仍在用）混淆。

## What Changes

- 从 UrbanManagement `UrbanWeighingRecord` 实体、EF 映射与 migration 中**删除** `FdBuildLicenseNo` 列。
- 从 `UrbanWeighingRecordReceiveInputDto` 与 `ReceiveAsync` 落库逻辑中删除该字段。
- 从 MaterialClient `UrbanWeighingRecordSubmitDto` 删除 `fdBuildLicenseNo`（客户端本就未发送）。
- **BREAKING**：Receive 称重 API 不再接受或持久化 `fdBuildLicenseNo`；未知 JSON 字段由现有序列化策略忽略。
- **不改动**：`GovProject.FdBuildLicenseNo`、`LicenseInfo.FdBuildLicenseNo`、JWT/Legacy API、BasePlatform 项目目录同步。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `urban-weighing-api`: 实体与 Receive DTO 不再包含 `FdBuildLicenseNo`。
- `proid-data-pipeline`: 上云 DTO 与数据流不再要求传递/持久化称重记录级 `FdBuildLicenseNo`；`LicenseInfo` 侧对接码保留。

## Impact

- **UrbanManagement**：`UrbanWeighingRecord` 实体、`UrbanWeighingRecordAppService.ReceiveAsync`、`UrbanWeighingRecordReceiveInputDto`、EF migration（drop column）。
- **MaterialClient**：`UrbanWeighingRecordSubmitDto` 删除属性；`UrbanServerUploadService` 无需再映射该字段。
- **OpenSpec**：`urban-weighing-api`、`proid-data-pipeline` delta specs。
- **无影响**：Gov 出站、进出记录、项目 CRUD、授权 JWT、Legacy `/Api/Post`。
