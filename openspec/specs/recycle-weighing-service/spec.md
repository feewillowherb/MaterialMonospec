# Recycle Weighing Service

## Purpose

定义 Recycle 模式独立领域服务 API，供 Recycle ViewModel 保存/完成运单与称重记录，与 SolidWaste 专用写入路径隔离。

## Requirements

### Requirement: IRecycleWeighingService 独立领域 API
系统 SHALL 定义 `IRecycleWeighingService` 接口及实现，供 Recycle ViewModel 保存/完成运单与称重记录，SHALL NOT 调用 `UpdateSolidWasteModeAsync`。

#### Scenario: Recycle VM 保存调用 Recycle API
- **WHEN** `RecycleWeighingDetailViewModel` 执行保存
- **THEN** SHALL 调用 `IRecycleWeighingService.UpdateRecycleModeAsync`
- **AND** SHALL NOT 调用 `IWeighingMatchingService.UpdateSolidWasteModeAsync`

#### Scenario: 写入字段不含 SolidWaste ExtraProperties
- **WHEN** `UpdateRecycleModeAsync` 更新 Waybill 或 WeighingRecord
- **THEN** SHALL 更新车牌、供应商、材料、备注、DeliveryType 等业务字段
- **AND** SHALL NOT 写入联单编号、镇街、SolidWaste 类型等 ExtraProperties

### Requirement: UpdateRecycleModeInput 入参定义
系统 SHALL 定义 `UpdateRecycleModeInput` record，包含 `ItemType`、`Id`、`PlateNumber`、`ProviderId`、`MaterialId`、`MaterialUnitId`、`DeliveryType`、`Remark`；SHALL NOT 包含 SolidWaste 专用字段。

#### Scenario: 入参类型为命名 record
- **WHEN** 定义 `UpdateRecycleModeAsync` 方法签名
- **THEN** 入参 SHALL 为 `UpdateRecycleModeInput` record
- **AND** SHALL NOT 使用 C# tuple 作为参数或返回值类型

### Requirement: 数据变更方法使用 UnitOfWork
`IRecycleWeighingService` 中涉及数据库写入的方法 SHALL 使用 `[UnitOfWork]` 特性修饰。

#### Scenario: 保存方法事务边界
- **WHEN** `UpdateRecycleModeAsync` 执行写入
- **THEN** 方法 SHALL 标注 `[UnitOfWork]`
- **AND** 异常时 SHALL 触发事务回滚
