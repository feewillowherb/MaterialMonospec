## ADDED Requirements

### Requirement: 称重记录接收透传 SubmitMachineCode

UrbanManagement 接收称重数据时 SHALL 从上传 DTO 的 `submitMachineCode` 透传写入 `UrbanWeighingRecord.SubmitMachineCode`，**仅记录不校验**（MUST NOT 比对提交机器码与授权机器码是否一致）。

#### Scenario: 接收并透传提交机器码

- **WHEN** `ReceiveAsync` 接收含 `submitMachineCode` 的提交 DTO
- **THEN** SHALL 将 `submitMachineCode` 写入 `UrbanWeighingRecord.SubmitMachineCode`
- **AND** MUST NOT 校验该值是否与 `GovProject.MachineCode` 或授权机器码一致

#### Scenario: 字段缺省允许为空

- **WHEN** 提交 DTO 未携带 `submitMachineCode`（历史客户端或异常）
- **THEN** `UrbanWeighingRecord.SubmitMachineCode` SHALL 允许为 null
- **AND** SHALL NOT 因该字段缺失而拒绝接收

#### Scenario: 数据库列新增

- **WHEN** UrbanManagement 应用迁移
- **THEN** `UrbanWeighingRecords` 表 SHALL 新增 `SubmitMachineCode NVARCHAR(128) NULL` 列
- **AND** EF Core 映射 SHALL 正确映射 `SubmitMachineCode` 属性

## MODIFIED Requirements

### Requirement: 称重记录入库审计时间

`UrbanWeighingRecord` 的「服务端入库时间」SHALL 由 `IHasCreationTime`（ABP/EF Core 自动填充 `CreationTime`）表达，SHALL NOT 在 `ReceiveAsync` 中手动设置 `AddTime = DateTime.Now`（语义等价，见 `abp-audit-field-standardization`）。

#### Scenario: 入库时间由框架自动填充

- **WHEN** `ReceiveAsync` 持久化 `UrbanWeighingRecord`
- **THEN** `CreationTime` SHALL 由框架自动填充为入库时间
- **AND** 代码中手动赋值 `AddTime` 的逻辑 SHALL 被移除
- **AND** 历史 `AddTime` 数据 SHALL 经迁移保留至 `CreationTime`
