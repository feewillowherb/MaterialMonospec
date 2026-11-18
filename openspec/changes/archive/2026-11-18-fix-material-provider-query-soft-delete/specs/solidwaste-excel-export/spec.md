## ADDED Requirements

### Requirement: 导出主数据名称解析包含软删
固废导出在构建材料字典、供应商字典，以及按货名 / 发货单位名称过滤时，SHALL 包含 `IsDeleted == true` 且行仍存在的 `Material` / `Provider`。

#### Scenario: 软删材料仍导出货名
- **WHEN** 已完成固废运单的 `MaterialId` 指向 `IsDeleted == true` 的 Material
- **THEN** Excel「货  名」列 SHALL 为该 Material 的 `Name`，不为空字符串

#### Scenario: 软删供应商仍参与发货/收货单位
- **WHEN** 运单的 `ProviderId` 指向 `IsDeleted == true` 的 Provider
- **THEN** `providerName` SHALL 取该 Provider 的 `ProviderName`，并参与 `GetSolidWasteShippingAndReceivingUnits` 计算

#### Scenario: 按软删货名过滤仍命中运单
- **WHEN** `SolidWasteExportFilter.GoodsName` 匹配某已软删 Material 的 `Name`
- **THEN** 系统 SHALL 返回 `MaterialId` 指向该 Material 的运单

## MODIFIED Requirements

### Requirement: 导出列结构对齐模板
系统 SHALL 按照以下 18 列顺序输出 Excel 数据：流水号、车号、称重类型、发货单位、收货单位、货名、毛重、皮重、净重、备注、毛重时间、皮重时间、所属街道、类型、联单编号、上传结果、上传状态、上传时间。

#### Scenario: 表头行与模板完全一致
- **WHEN** 生成的 Excel 文件被打开
- **THEN** 第一行（表头）SHALL 包含以下 18 列标题，顺序为：流水号、车号、称重类型、发货单位、收货单位、货名、毛重、皮重、净重、备注、毛重时间、皮重时间、所属街道、类型、联单编号、上传结果、上传状态、上传时间

#### Scenario: 字段映射正确性
- **WHEN** 一条固废运单被导出
- **THEN** 各字段 SHALL 按以下规则映射：流水号=`Waybill.OrderNo`，车号=`Waybill.PlateNumber`，称重类型=`DeliveryType` 映射（Receiving→"收料"，Sending→"发料"），发货/收货单位=`waybill.GetSolidWasteShippingAndReceivingUnits(providerName)` 的结果，货名=`Material.Name`（通过 `Waybill.MaterialId` 直接字段关联，**含软删 Material**），毛重=`OrderTotalWeight`，皮重=`OrderTruckWeight`，净重=`OrderGoodsWeight`，备注=`Remark`，毛重时间=`JoinTime`，皮重时间=`OutTime`，所属街道=`Waybill.GetSolidWasteStreet()`，类型=`Waybill.GetSolidWasteType()`，联单编号=`Waybill.GetSolidWasteOrderNumber()`

#### Scenario: 收料模式下发货/收货单位正确映射
- **WHEN** 运单 `DeliveryType` 为 `Receiving`，`providerName` 为 "长巷村"，`Shipper` 属性为 "东部资源化处置点"
- **THEN** 发货单位 SHALL 为 "长巷村"，收货单位 SHALL 为 "东部资源化处置点"

#### Scenario: 发料模式下发货/收货单位对调
- **WHEN** 运单 `DeliveryType` 为 `Sending`，`providerName` 为 "长巷村"，`Shipper` 属性为 "东部资源化处置点"
- **THEN** 发货单位 SHALL 为 "东部资源化处置点"，收货单位 SHALL 为 "长巷村"

#### Scenario: Shipper 未设置时使用默认值
- **WHEN** 运单的 Shipper 属性未设置（为 null），`DeliveryType` 为 `Receiving`，`providerName` 为 "长巷村"
- **THEN** 发货单位 SHALL 为 "长巷村"，收货单位 SHALL 为 "东部资源化处置点"（默认值）

#### Scenario: Shipper 未设置时发料模式对调仍使用默认值
- **WHEN** 运单的 Shipper 属性未设置（为 null），`DeliveryType` 为 `Sending`，`providerName` 为 "长巷村"
- **THEN** 发货单位 SHALL 为 "东部资源化处置点"（默认值），收货单位 SHALL 为 "长巷村"

#### Scenario: 关联实体硬缺失时安全处理
- **WHEN** 运单的 ProviderId 或 `Waybill.MaterialId` 在对应表中**不存在任何行**
- **THEN** 对应的发货单位或货名字段 SHALL 输出为空字符串，不抛出异常

#### Scenario: 关联实体仅软删除时仍输出名称
- **WHEN** 运单的 ProviderId 或 `Waybill.MaterialId` 指向存在且 `IsDeleted == true` 的记录
- **THEN** 对应的发货单位或货名字段 SHALL 输出该记录的名称，不为空字符串
- **AND** SHALL NOT 抛出异常
