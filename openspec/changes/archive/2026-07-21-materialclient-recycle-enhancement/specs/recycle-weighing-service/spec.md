# Recycle Weighing Service

## MODIFIED Requirements

### Requirement: UpdateRecycleModeInput 入参定义
系统 SHALL 定义 `UpdateRecycleModeInput` record，包含 `ItemType`、`Id`、`PlateNumber`、`ProviderId`、`MaterialId`、`MaterialUnitId`、`DeliveryType`、`Remark`、`UnitPrice`、`SaleContractNo`；SHALL NOT 包含 SolidWaste 专用字段。

#### Scenario: 入参类型为命名 record
- **WHEN** 定义 `UpdateRecycleModeAsync` 方法签名
- **THEN** 入参 SHALL 为 `UpdateRecycleModeInput` record
- **AND** SHALL NOT 使用 C# tuple 作为参数或返回值类型

#### Scenario: 单价与合同号持久化到 Waybill
- **WHEN** `ItemType=Waybill` 且 `UnitPrice=120`、`SaleContractNo="HT-001"`
- **THEN** `UpdateRecycleModeAsync` SHALL 将 `UnitPrice`、`SaleContractNo` 写入 `Waybill` 对应列
- **AND** WHEN 两者为 null SHALL 将对应列置空

#### Scenario: 录入字段触发待上报
- **WHEN** `UpdateRecycleModeAsync` 写入 `UnitPrice`/`SaleContractNo` 后
- **THEN** SHALL 维持既有 `SetPendingSync()` 行为
- **AND** 后台同步 SHALL 能在后续轮次读取这些列
