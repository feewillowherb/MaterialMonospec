## MODIFIED Requirements

### Requirement: 称重记录业务服务

UrbanManagement SHALL 提供 `IUrbanWeighingRecordAppService` 处理称重记录业务逻辑。

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
- **AND** SHALL 设置 AddTime = DateTime.Now
- **AND** SHALL 返回新记录 Id
