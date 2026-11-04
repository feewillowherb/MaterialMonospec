## ADDED Requirements

### Requirement: 毛皮净 Displayed 吨舍入口径
系统 SHALL 将固废对外展示用的毛重、皮重、净重（吨）统一为 UI `F2` 同口径：`Math.Round(rawTon, 2, MidpointRounding.AwayFromZero)`。该舍入 MUST 通过 `MaterialMath` 的 Displayed 吨 API（如 `RoundToDisplayedTon`）完成，供导出映射与千克换算复用；MUST NOT 回写 `Waybill` 库内原值。

#### Scenario: 皮重三位小数圆到两位
- **WHEN** 库内 `OrderTruckWeight` 为 `6.045`
- **THEN** Displayed 吨 MUST 为 `6.05`

#### Scenario: 净重三位小数圆到两位
- **WHEN** 库内 `OrderGoodsWeight` 为 `6.995`
- **THEN** Displayed 吨 MUST 为 `7.00`

#### Scenario: 圆后毛减皮可以不等于净
- **WHEN** 毛/皮/净分别按 Displayed 口径舍入后，毛 − 皮 与净不相等
- **THEN** 系统 MUST 仍分别输出各字段的 Displayed 值，MUST NOT 用毛 − 皮重算净重

### Requirement: 固废小票毛皮净千克对齐 UI Displayed 吨
`WeighingMatchingService.CreateWeighingTicketDtoAsync` 在将运单吨重写入 `WeighingTicketDto` 的毛重/皮重/净重（千克）时，MUST 使用 `MaterialMath.ConvertDisplayedTonToKg`（先 Displayed 吨再换整数千克），使小票与有人值守固废 UI 的 `F2` 吨显示一致。

#### Scenario: 皮重打印千克与 UI 一致
- **WHEN** `OrderTruckWeight` 为 `6.045` 且 UI 显示 `6.05` 吨
- **THEN** 票据 DTO 皮重 MUST 为 `6050` 千克（而非 `6045`）

#### Scenario: 净重打印千克与 UI 一致
- **WHEN** `OrderGoodsWeight` 为 `6.995` 且 UI 显示 `7.00` 吨
- **THEN** 票据 DTO 净重 MUST 为 `7000` 千克（而非 `6995`）

## MODIFIED Requirements

### Requirement: 导出列结构对齐模板
系统 SHALL 按照以下 18 列顺序输出 Excel 数据：流水号、车号、称重类型、发货单位、收货单位、货名、毛重、皮重、净重、备注、毛重时间、皮重时间、所属街道、类型、联单编号、上传结果、上传状态、上传时间。

#### Scenario: 表头行与模板完全一致
- **WHEN** 生成的 Excel 文件被打开
- **THEN** 第一行（表头）SHALL 包含以下 18 列标题，顺序为：流水号、车号、称重类型、发货单位、收货单位、货名、毛重、皮重、净重、备注、毛重时间、皮重时间、所属街道、类型、联单编号、上传结果、上传状态、上传时间

#### Scenario: 字段映射正确性
- **WHEN** 一条固废运单被导出
- **THEN** 各字段 SHALL 按以下规则映射：流水号=`Waybill.OrderNo`，车号=`Waybill.PlateNumber`，称重类型=`DeliveryType` 映射（Receiving→"收料"，Sending→"发料"），发货/收货单位=`waybill.GetSolidWasteShippingAndReceivingUnits(providerName)` 的结果，货名=`Material.Name`（通过 `Waybill.MaterialId` 直接字段关联），毛重=`Displayed(OrderTotalWeight)`，皮重=`Displayed(OrderTruckWeight)`，净重=`Displayed(OrderGoodsWeight)`（Displayed = `Round(..., 2, AwayFromZero)`，与 UI `F2` 同口径），备注=`Remark`，毛重时间=`JoinTime`，皮重时间=`OutTime`，所属街道=`Waybill.GetSolidWasteStreet()`，类型=`Waybill.GetSolidWasteType()`，联单编号=`Waybill.GetSolidWasteOrderNumber()`

#### Scenario: 导出毛皮净与 UI 两位一致
- **WHEN** 运单库内皮重为 `6.045`、净重为 `6.995` 且 UI 分别显示 `6.05`、`7.00` 吨
- **THEN** Excel（及同源 `SolidWasteExportRow` / 数据管理列表）皮重列 MUST 为 `6.05`，净重列 MUST 为 `7.00`，MUST NOT 输出未舍入的 `6.045` / `6.995`

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

#### Scenario: 关联实体不存在时安全处理
- **WHEN** 运单的 ProviderId 或 `Waybill.MaterialId` 指向已删除或不存在的记录
- **THEN** 对应的发货单位或货名字段 SHALL 输出为空字符串，不抛出异常

### Requirement: 导出汇总行
系统 SHALL 在数据行之后追加一行汇总行，格式与 `sample.csv` 末尾行一致。汇总行的毛重、皮重、净重之和 MUST 等于各数据行上**已按 Displayed 口径舍入后**的对应列之和（先按行舍入再求和）。

#### Scenario: 汇总行内容正确
- **WHEN** 导出包含 N 条运单数据
- **THEN** 汇总行的第 1 列 SHALL 为运单总数 N，第 7 列为所有（已 Displayed）毛重之和，第 8 列为所有（已 Displayed）皮重之和，第 9 列为所有（已 Displayed）净重之和，其余列为空

#### Scenario: 汇总等于导出行之和
- **WHEN** 导出行皮重经 Displayed 后分别为 `6.05` 与 `1.00`
- **THEN** 汇总行皮重列 MUST 为 `7.05`（对已圆行求和），MUST NOT 用未舍入库值求和后再单独改口径
