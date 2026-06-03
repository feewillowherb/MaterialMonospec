## ADDED Requirements

### Requirement: Urban 上云重量单位换算

MaterialClient.Urban 在向 UrbanManagement 提交称重记录（`Receive` / `UrbanWeighingRecordSubmitDto`）时，MUST 将本地 `WeighingRecord.TotalWeight`（吨）转换为千克后再赋值给 `totalWeight` 字段。

#### Scenario: 标准吨位上云

- **WHEN** 本地记录 `TotalWeight` 为 `8.50`（吨）
- **AND** `UrbanServerUploadService` 构建上云 DTO
- **THEN** 请求 JSON 中 `totalWeight` MUST 为 `8500`（千克，按 `MaterialMath.ConvertTonToKg` 舍入）

#### Scenario: 零或负重量不上云

- **WHEN** 本地 `TotalWeight` 小于等于 0
- **THEN** 系统 MUST NOT 调用 `Receive`（与现有上云校验一致）
- **OR** 若调用则服务端 MUST 拒绝无效重量

#### Scenario: 本地存储单位不变

- **WHEN** 上云换算完成并成功 `Receive`
- **THEN** 本地 SQLite `WeighingRecord.TotalWeight` MUST 仍为吨
- **AND** Urban 称重区 UI MUST 仍按吨展示
