## ADDED Requirements

### Requirement: UrbanWeighingExtension 提交机器码字段

MaterialClient `UrbanWeighingExtension` 实体 SHALL 新增 `SubmitMachineCode`（可空字符串），记录客户端提交该称重数据时的机器码，用于数据溯源。提交时 SHALL 由 `MachineCodeService.GetMachineCode()`（或等价服务）写入本机机器码。

#### Scenario: 创建 Extension 时写入提交机器码

- **WHEN** 客户端创建/更新 `UrbanWeighingExtension` 准备上传
- **THEN** `SubmitMachineCode` SHALL 由本机 `MachineCodeService.GetMachineCode()` 填充
- **AND** 该值 SHALL 随上传 DTO 一并发送

#### Scenario: 上传 DTO 携带 submitMachineCode

- **WHEN** `UrbanServerUploadService` 构造 `UrbanWeighingRecordSubmitDto`
- **THEN** DTO SHALL 包含 `submitMachineCode` 字段
- **AND** 该字段 SHALL 取自 `UrbanWeighingExtension.SubmitMachineCode`

#### Scenario: 数据库列新增

- **WHEN** MaterialClient（SQLite）应用迁移
- **THEN** `UrbanWeighingExtensions` 表 SHALL 新增 `SubmitMachineCode TEXT NULL` 列
- **AND** 历史 NULL 值 SHALL 不阻断既有数据读取
