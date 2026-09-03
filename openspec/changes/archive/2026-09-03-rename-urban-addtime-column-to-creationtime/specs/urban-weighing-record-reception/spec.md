## MODIFIED Requirements

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
  - CreationTime (DateTime, 服务端入库时间；ABP `IHasCreationTime`；DB 列名 `CreationTime`)
  - SyncType (int?)
  - IsAnomaly (bool)
  - AnomalyReason (string?)
  - ExtraProperties (ExtraPropertyDictionary, via IHasExtraProperties)
- **AND** SHALL NOT contain a dedicated `EditHistoryJson` property
- **AND** MUST NOT expose an `AddTime` property on the entity

#### Scenario: ClientRecordId 唯一约束
- **WHEN** 插入重复 ClientRecordId 的记录
- **THEN** SHALL 违反唯一约束，触发幂等处理逻辑

### Requirement: 称重记录业务服务

UrbanManagement SHALL 提供 `IUrbanWeighingRecordAppService` 处理称重记录业务逻辑。Edit history data SHALL be read from and written to entity `ExtraProperties` rather than a dedicated JSON field.

#### Scenario: 接收并去重

- **WHEN** ReceiveAsync 被调用且 ClientRecordId 已存在
- **THEN** SHALL 返回已有记录 Id
- **AND** SHALL NOT 插入新记录
- **AND** SHALL 使用入参 DTO 更新已有记录的 `PlateNumber`、`TotalWeight`、`IsAnomaly`、`AnomalyReason`
- **AND** if input DTO contains `ExtraProperties["EditHistory"]`, SHALL replace the entity's `ExtraProperties["EditHistory"]` with that value
- **AND** SHALL update client sync metadata fields (`ClientSyncType`, `ClientSyncTime`, `ClientRetryCount`, `ClientLastErrorTime`) when provided
- **AND** if input `IsAnomaly` is `false`, SHALL set `SyncType = 0` and `RetryCount = 0` on the existing record
- **AND** SHALL NOT link, replace, or remove attachments regardless of `AttachmentIds` in the payload

#### Scenario: 接收新记录并关联附件

- **WHEN** ReceiveAsync 被调用且 ClientRecordId 不存在
- **AND** input includes `AttachmentIds`
- **THEN** SHALL create the new record
- **AND** SHALL link the specified attachments via `LinkAttachmentsAsync`

#### Scenario: 接收新记录

- **WHEN** ReceiveAsync 被调用且 ClientRecordId 不存在
- **THEN** SHALL 创建新 UrbanWeighingRecord
- **AND** SHALL 由 ABP 审计填充 `CreationTime`（MUST NOT 手写 `AddTime`）
- **AND** if input DTO contains `ExtraProperties["EditHistory"]`, SHALL copy the edit history value to the entity's `ExtraProperties["EditHistory"]`
- **AND** SHALL NOT write to a dedicated `EditHistoryJson` property
- **AND** SHALL 返回新记录 Id

### Requirement: DTO mapping for urban weighing records
The system SHALL provide DTO classes with entity mapping methods for weighing records. Output DTOs SHALL expose edit history via `ExtraProperties` dictionary.

#### Scenario: FromEntity mapping for output
- **WHEN** calling `UrbanWeighingRecordOutputDto.FromEntity(entity)`
- **THEN** system creates DTO with all entity properties mapped correctly
- **AND** the DTO SHALL expose `CreationTime` sourced from `entity.CreationTime`
- **AND** the DTO MUST NOT expose `AddTime`
- **AND** the DTO's `ExtraProperties` dictionary MUST contain the entity's ExtraProperties entries (including edit history)
- **AND** the DTO MUST NOT contain a dedicated `EditHistoryJson` property
