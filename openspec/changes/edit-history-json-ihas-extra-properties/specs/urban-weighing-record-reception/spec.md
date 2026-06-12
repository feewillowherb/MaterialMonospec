## MODIFIED Requirements

### Requirement: 称重记录 DTO 格式

UrbanManagement SHALL 定义称重记录接收 DTO，包含 MaterialClient 传输的必要字段。`TotalWeight` 字段 MUST 以**千克（kg）**表示；MaterialClient 在构建 DTO 前 MUST 将本地吨值换算为千克。DTO SHALL include an `ExtraProperties` dictionary for passing extension data such as edit history, replacing dedicated `EditHistoryJson` property.

#### Scenario: DTO 包含必要字段
- **WHEN** MaterialClient 构建称重记录 DTO
- **THEN** DTO SHALL 包含以下字段：ClientRecordId (long)、PlateNumber (string?)、TotalWeight (decimal, **kg**)、WeighingTime (DateTime)、SyncType (int?)
- **AND** DTO SHALL NOT contain a dedicated `EditHistoryJson` property
- **AND** DTO SHALL include an `ExtraProperties` dictionary (`Dictionary<string, object?>?`) for passing extension data

#### Scenario: Edit history transmitted via ExtraProperties
- **WHEN** MaterialClient sends edit history with a weighing record
- **THEN** the edit history JSON string MUST be placed in `ExtraProperties["EditHistory"]`
- **AND** the API MUST NOT look for edit history in a top-level `editHistoryJson` field

### Requirement: UrbanWeighingRecord 实体定义

UrbanManagement SHALL 定义 `UrbanWeighingRecord` 实体，映射到 `Urban_WeighingRecord` 表。The entity SHALL implement `IHasExtraProperties` for storing extension data.

#### Scenario: 实体字段
- **WHEN** 定义 UrbanWeighingRecord
- **THEN** SHALL 包含以下属性：
  - Id (long, 自增主键)
  - ClientRecordId (long, 客户端记录 ID，唯一索引)
  - PlateNumber (string?)
  - TotalWeight (decimal, 千克)
  - WeighingTime (DateTime)
  - AddTime (DateTime, 服务端入库时间)
  - SyncType (int?)
  - IsAnomaly (bool)
  - AnomalyReason (string?)
  - ExtraProperties (ExtraPropertyDictionary, via IHasExtraProperties)
- **AND** SHALL NOT contain a dedicated `EditHistoryJson` property

#### Scenario: ClientRecordId 唯一约束
- **WHEN** 插入重复 ClientRecordId 的记录
- **THEN** SHALL 违反唯一约束，触发幂等处理逻辑

### Requirement: 称重记录业务服务

UrbanManagement SHALL 提供 `IUrbanWeighingRecordAppService` 处理称重记录业务逻辑。Edit history data SHALL be read from and written to entity `ExtraProperties` rather than a dedicated JSON field.

#### Scenario: 接收并去重
- **WHEN** ReceiveAsync 被调用且 ClientRecordId 已存在
- **THEN** SHALL 返回已有记录 Id
- **AND** SHALL NOT 插入新记录

#### Scenario: 接收新记录并存储编辑历史
- **WHEN** ReceiveAsync 被调用且 ClientRecordId 不存在
- **THEN** SHALL 创建新 UrbanWeighingRecord
- **AND** SHALL 设置 AddTime = DateTime.Now
- **AND** if input DTO contains `ExtraProperties["EditHistory"]`, SHALL copy the edit history value to the entity's `ExtraProperties["EditHistory"]`
- **AND** SHALL NOT write to a dedicated `EditHistoryJson` property
- **AND** SHALL 返回新记录 Id

### Requirement: DTO mapping for urban weighing records
The system SHALL provide DTO classes with entity mapping methods for weighing records. Output DTOs SHALL expose edit history via `ExtraProperties` dictionary.

#### Scenario: FromEntity mapping for output
- **WHEN** calling `UrbanWeighingRecordOutputDto.FromEntity(entity)`
- **THEN** system creates DTO with all entity properties mapped correctly
- **AND** the DTO's `ExtraProperties` dictionary MUST contain the entity's ExtraProperties entries (including edit history)
- **AND** the DTO MUST NOT contain a dedicated `EditHistoryJson` property
