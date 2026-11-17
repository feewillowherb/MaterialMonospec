## MODIFIED Requirements

### Requirement: IRecycleWeighingService 独立领域 API
系统 SHALL 定义 `IRecycleWeighingService` 接口及实现，供 Recycle ViewModel 保存/完成运单与称重记录，SHALL NOT 调用 `UpdateSolidWasteModeAsync`。

#### Scenario: Recycle VM 保存调用 Recycle API
- **WHEN** `RecycleWeighingDetailViewModel` 执行保存
- **THEN** SHALL 调用 `IRecycleWeighingService.UpdateRecycleModeAsync`
- **AND** SHALL NOT 调用 `IWeighingMatchingService.UpdateSolidWasteModeAsync`

#### Scenario: 写入采集字段
- **WHEN** `UpdateRecycleModeAsync` 更新 Waybill 或 WeighingRecord
- **THEN** SHALL 更新车牌、备注、DeliveryType（若仍使用）及毛重相关采集字段
- **AND** SHALL NOT 要求写入供应商或材料作为完成前提
- **AND** SHALL NOT 写入联单编号、镇街、SolidWaste 类型等 ExtraProperties

### Requirement: UpdateRecycleModeInput 入参定义
系统 SHALL 定义 `UpdateRecycleModeInput` record，包含采集所需字段（至少 `ItemType`、`Id`、`PlateNumber`、`Remark`，以及实现仍需要的 `DeliveryType`）；SHALL NOT 将 `UnitPrice`、`SaleContractNo`、`ProviderId`、`MaterialId` 作为采集必填项。入参与返回值 SHALL NOT 使用 C# tuple。

#### Scenario: 入参类型为命名 record
- **WHEN** 定义 `UpdateRecycleModeAsync` 方法签名
- **THEN** 入参 SHALL 为 `UpdateRecycleModeInput` record
- **AND** SHALL NOT 使用 C# tuple 作为参数或返回值类型

#### Scenario: 保存不依赖单价合同
- **WHEN** 调用 `UpdateRecycleModeAsync` 且未提供单价与合同号
- **THEN** 保存 SHALL 成功
- **AND** SHALL NOT 因缺少单价/合同失败
