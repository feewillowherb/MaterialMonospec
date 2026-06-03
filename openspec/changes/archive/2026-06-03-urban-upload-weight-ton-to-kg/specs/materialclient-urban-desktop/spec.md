## ADDED Requirements

### Requirement: 称重记录上云重量换算

MaterialClient.Urban 的 `IUrbanServerUploadService` / `UrbanServerUploadService` 在轮询上云（`PollingBackgroundService`）提交称重元数据时，MUST 使用 `MaterialMath.ConvertTonToKg` 将 `WeighingRecord.TotalWeight` 转为千克后写入 Refit DTO，不得原样提交吨值。

#### Scenario: 上云 DTO 使用千克

- **WHEN** `SubmitRecordAsync` 为 Pending 记录调用 `ReceiveWeighingRecordAsync`
- **THEN** `UrbanWeighingRecordSubmitDto.TotalWeight` MUST 等于 `ConvertTonToKg(record.TotalWeight)`
- **AND** MUST NOT 等于未换算的 `record.TotalWeight`（除非吨值本身为 0）
