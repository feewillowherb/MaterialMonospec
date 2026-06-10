## MODIFIED Requirements

### Requirement: 称重记录 DTO 格式

UrbanManagement SHALL 定义称重记录接收 DTO，包含 MaterialClient 传输的必要字段。`TotalWeight` 字段 MUST 以**千克（kg）**表示；MaterialClient 在构建 DTO 前 MUST 将本地吨值换算为千克。

#### Scenario: DTO 包含必要字段

- **WHEN** MaterialClient 构建称重记录 DTO
- **THEN** DTO SHALL 包含以下字段：ClientRecordId (long)、PlateNumber (string?)、TotalWeight (decimal, **kg**)、WeighingTime (DateTime)、SyncType (int?)
