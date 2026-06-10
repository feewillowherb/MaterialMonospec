## ADDED Requirements

### Requirement: Receive 载荷 TotalWeight 单位为千克

`UrbanWeighingRecordReceiveInputDto.totalWeight`（及持久化字段 `UrbanWeighingRecord.TotalWeight`）SHALL 表示车辆总重，单位为**千克（kg）**。MaterialClient.Urban 上云时 MUST 在客户端完成吨→千克换算；UrbanManagement MUST NOT 假定该字段为吨。

#### Scenario: 接收并持久化千克重量

- **WHEN** `ReceiveAsync` 收到 `totalWeight: 8500`
- **THEN** 新建的 `UrbanWeighingRecord.TotalWeight` MUST 存为 `8500`
- **AND** 政府同步构造载荷时 `grossWeight` / `goodsWeight` MUST 使用该千克值

#### Scenario: 政府车型阈值按千克

- **WHEN** 已存 `TotalWeight` 为 `5000`（kg）
- **AND** `GovSyncBackgroundWorker` 构建政府载荷
- **THEN** `carType` MUST 为 `Large`（因大于 4500 kg 阈值）
