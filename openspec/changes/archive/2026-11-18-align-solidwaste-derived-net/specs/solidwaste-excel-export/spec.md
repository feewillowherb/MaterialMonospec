## ADDED Requirements

### Requirement: 固废净重由 Displayed 毛皮派生
固废对外毛重、皮重、净重（UI 净重块、详情、Excel / `SolidWasteExportRow`、小票千克）MUST 满足逻辑恒等：先将毛、皮按 Displayed 吨口径（`Round(..., 2, AwayFromZero)`）处理后，净重 MUST 为毛′ − 皮′（吨）或对应毛 kg − 皮 kg；MUST NOT 使用对库内 `OrderGoodsWeight` 的独立 Displayed 舍入作为对外净重。MUST NOT 回写 Waybill。

#### Scenario: 导出净重等于毛减皮
- **WHEN** 库内毛 `13.04`、皮 `6.045`、净 `6.995`
- **THEN** 导出行 MUST 为毛 `13.04`、皮 `6.05`、净 `6.99`（`13.04 − 6.05`），MUST NOT 为 `7.00`

#### Scenario: 小票净千克等于毛减皮千克
- **WHEN** Displayed 毛/皮换算后毛 kg 为 `13040`、皮 kg 为 `6050`
- **THEN** 票据 DTO 净重 MUST 为 `6990`，MUST NOT 为独立 `ConvertDisplayedTonToKg(6.995)` 的 `7000`

#### Scenario: 主界面固废净重块派生
- **WHEN** 选中固废已完成运单且毛/皮可 Displayed
- **THEN** 净重块 MUST 显示 `毛′ − 皮′` 吨（F2），MUST NOT 仅格式化 `OrderGoodsWeight`

## MODIFIED Requirements

### Requirement: 毛皮净 Displayed 吨舍入口径
系统 SHALL 将固废对外展示用的毛重、皮重统一为 UI `F2` 同口径：`Math.Round(rawTon, 2, MidpointRounding.AwayFromZero)`（`MaterialMath.RoundToDisplayedTon`）。净重 MUST 由 Displayed 毛、皮相减得到，MUST NOT 对库净单独 Round 后作为对外净重。MUST NOT 回写 `Waybill` 库内原值。

#### Scenario: 皮重三位小数圆到两位
- **WHEN** 库内 `OrderTruckWeight` 为 `6.045`
- **THEN** Displayed 皮重 MUST 为 `6.05`

#### Scenario: 净重由毛皮派生而非独立圆库净
- **WHEN** 库内毛 `13.04`、皮 `6.045`、净 `6.995`
- **THEN** Displayed 净重 MUST 为 `6.99`，MUST NOT 为 `7.00`

### Requirement: 固废小票毛皮净千克对齐 UI Displayed 吨
`WeighingMatchingService.CreateWeighingTicketDtoAsync` 在将运单吨重写入 `WeighingTicketDto` 时，毛重/皮重 MUST 使用 `MaterialMath.ConvertDisplayedTonToKg`；净重千克 MUST 等于毛千克减去皮千克，使小票与有人值守固废 UI 逻辑恒等。

#### Scenario: 皮重打印千克与 UI 一致
- **WHEN** `OrderTruckWeight` 为 `6.045` 且 UI 显示 `6.05` 吨
- **THEN** 票据 DTO 皮重 MUST 为 `6050` 千克

#### Scenario: 净重打印为毛减皮
- **WHEN** 毛 Displayed→kg 为 `13040`、皮为 `6050`
- **THEN** 票据 DTO 净重 MUST 为 `6990` 千克

### Requirement: 导出列结构对齐模板
系统 SHALL 按照以下 18 列顺序输出 Excel 数据：流水号、车号、称重类型、发货单位、收货单位、货名、毛重、皮重、净重、备注、毛重时间、皮重时间、所属街道、类型、联单编号、上传结果、上传状态、上传时间。

#### Scenario: 表头行与模板完全一致
- **WHEN** 生成的 Excel 文件被打开
- **THEN** 第一行（表头）SHALL 包含以下 18 列标题，顺序为：流水号、车号、称重类型、发货单位、收货单位、货名、毛重、皮重、净重、备注、毛重时间、皮重时间、所属街道、类型、联单编号、上传结果、上传状态、上传时间

#### Scenario: 字段映射正确性
- **WHEN** 一条固废运单被导出
- **THEN** 各字段 SHALL 按以下规则映射：流水号=`Waybill.OrderNo`，车号=`Waybill.PlateNumber`，称重类型=`DeliveryType` 映射（Receiving→"收料"，Sending→"发料"），发货/收货单位=`waybill.GetSolidWasteShippingAndReceivingUnits(providerName)` 的结果，货名=`Material.Name`（通过 `Waybill.MaterialId` 直接字段关联），毛重=`Displayed(OrderTotalWeight)`，皮重=`Displayed(OrderTruckWeight)`，净重=`Displayed(OrderTotalWeight) − Displayed(OrderTruckWeight)`，备注=`Remark`，毛重时间=`JoinTime`，皮重时间=`OutTime`，所属街道=`Waybill.GetSolidWasteStreet()`，类型=`Waybill.GetSolidWasteType()`，联单编号=`Waybill.GetSolidWasteOrderNumber()`

#### Scenario: 导出毛皮净与 UI 两位一致且毛减皮等于净
- **WHEN** 运单库内毛 `13.04`、皮 `6.045`、净 `6.995`
- **THEN** Excel（及同源 `SolidWasteExportRow`）MUST 为毛 `13.04`、皮 `6.05`、净 `6.99`

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
系统 SHALL 在数据行之后追加一行汇总行，格式与 `sample.csv` 末尾行一致。汇总行的毛重、皮重、净重之和 MUST 等于各数据行上已按本 change 口径写出的对应列之和（先按行舍入/派生再求和）。

#### Scenario: 汇总行内容正确
- **WHEN** 导出包含 N 条运单数据
- **THEN** 汇总行的第 1 列 SHALL 为运单总数 N，第 7 列为所有毛重之和，第 8 列为所有皮重之和，第 9 列为所有净重之和，其余列为空

#### Scenario: 汇总等于导出行之和
- **WHEN** 导出行皮重经 Displayed 后分别为 `6.05` 与 `1.00`
- **THEN** 汇总行皮重列 MUST 为 `7.05`
