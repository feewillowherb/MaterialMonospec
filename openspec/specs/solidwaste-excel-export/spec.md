# Solid Waste Excel Export

## Purpose

Defines the solid-waste completed-waybill Excel export contract (18-column template, filters, summary row) and related ticket DTO shipping/receiving rules, including gross/tare/net Displayed-ton alignment with the attended weighing UI `F2` precision.

## Requirements

### Requirement: 固废运单 Excel 导出接口
系统 SHALL 提供 `ISolidWasteExcelExportService` 接口，支持将固废模式（`WeighingMode.SolidWaste`）的已完成运单导出为 `.xlsx` 格式的 Excel 文件。接口接受 `SolidWasteExportFilter` 过滤条件对象和输出文件路径，所有过滤参数均为可空。

#### Scenario: 使用完整过滤条件导出
- **WHEN** 调用 `ExportAsync(filter, outputPath)` 并传入包含日期范围、车牌号、货名、发货单位的过滤条件
- **THEN** 系统查询满足 `WeighingMode == SolidWaste` 且 `OrderType == Completed` 且 `AddDate` 在日期范围内、且匹配车牌号/货名/发货单位的所有 Waybill 记录，生成 `.xlsx` 文件到指定路径，并返回包含导出行数和成功状态的 `ExportResult`

#### Scenario: 所有过滤参数为 null 时导出全部数据
- **WHEN** 调用 `ExportAsync` 且 `SolidWasteExportFilter` 的所有属性均为 null
- **THEN** 系统导出全部满足 `WeighingMode == SolidWaste` 且 `OrderType == Completed` 的运单数据

#### Scenario: 仅传入部分过滤条件
- **WHEN** 调用 `ExportAsync` 且仅设置了 `StartDate` 和 `EndDate`，其余参数为 null
- **THEN** 系统仅按 `AddDate` 日期范围过滤，不过滤车牌号、货名和发货单位

#### Scenario: 过滤结果为空时导出空文件
- **WHEN** 调用 `ExportAsync` 但过滤条件匹配不到任何运单
- **THEN** 系统生成仅包含表头行的 `.xlsx` 文件，`ExportResult.RowCount` 为 0

### Requirement: 可空过滤参数定义
系统 SHALL 提供 `SolidWasteExportFilter` 过滤条件类，包含以下全部可空参数：`DateTime? StartDate`（AddDate 起始）、`DateTime? EndDate`（AddDate 截止）、`string? PlateNumber`（车牌号）、`string? GoodsName`（货名）、`string? ProviderName`（发货单位）。

#### Scenario: 车牌号模糊匹配
- **WHEN** 过滤条件中 `PlateNumber` 为 "浙A96"
- **THEN** 系统 SHALL 返回所有 `Waybill.PlateNumber` 包含 "浙A96" 的运单（Contains 匹配）

#### Scenario: 货名模糊匹配
- **WHEN** 过滤条件中 `GoodsName` 为 "装修"
- **THEN** 系统 SHALL 返回所有关联 Material.Name 包含 "装修" 的运单

#### Scenario: 发货单位模糊匹配
- **WHEN** 过滤条件中 `ProviderName` 为 "长巷"
- **THEN** 系统 SHALL 返回所有关联 Provider.ProviderName 包含 "长巷" 的运单

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

### Requirement: 货名过滤使用实体字段
系统 SHALL 在 `SolidWasteService.SolidWasteQueryWaybillsAsync` 中使用 `Waybill.MaterialId` 直接字段进行货名过滤，而非 ExtraProperties 扩展键。

#### Scenario: 通过货名过滤运单
- **WHEN** `SolidWasteExportFilter.GoodsName` 为 "装修"
- **THEN** 系统 SHALL 查询 `Material.Name` 包含 "装修" 的 Material 记录，返回 `Waybill.MaterialId` 匹配的运单

#### Scenario: MaterialId 为 null 的运单不参与货名过滤匹配
- **WHEN** 运单的 `MaterialId` 为 null 且 `GoodsName` 过滤条件不为空
- **THEN** 该运单 SHALL 被排除在过滤结果之外

### Requirement: 材料字典构建使用实体字段
系统 SHALL 在 `SolidWasteService.SolidWasteBuildMaterialDictAsync` 中使用 `Waybill.MaterialId` 直接字段收集材料 ID，而非 ExtraProperties 扩展键。

#### Scenario: 从运单收集材料 ID 构建字典
- **WHEN** 运单列表包含 `MaterialId` 为 10、20、10 的三条运单
- **THEN** 系统 SHALL 收集去重后的 `{10, 20}` 作为查询条件，返回 `{10: "装修垃圾", 20: "绿化垃圾"}` 的字典

#### Scenario: 所有运单 MaterialId 为 null 时返回空字典
- **WHEN** 所有运单的 `MaterialId` 均为 null
- **THEN** 系统 SHALL 返回空字典，不执行数据库查询

### Requirement: 导出汇总行
系统 SHALL 在数据行之后追加一行汇总行，格式与 `sample.csv` 末尾行一致。汇总行的毛重、皮重、净重之和 MUST 等于各数据行上**已按 Displayed 口径舍入后**的对应列之和（先按行舍入再求和）。

#### Scenario: 汇总行内容正确
- **WHEN** 导出包含 N 条运单数据
- **THEN** 汇总行的第 1 列 SHALL 为运单总数 N，第 7 列为所有（已 Displayed）毛重之和，第 8 列为所有（已 Displayed）皮重之和，第 9 列为所有（已 Displayed）净重之和，其余列为空

#### Scenario: 汇总等于导出行之和
- **WHEN** 导出行皮重经 Displayed 后分别为 `6.05` 与 `1.00`
- **THEN** 汇总行皮重列 MUST 为 `7.05`（对已圆行求和），MUST NOT 用未舍入库值求和后再单独改口径

### Requirement: 时间格式统一
系统 SHALL 将所有时间字段（毛重时间、皮重时间）格式化为 `yyyy-MM-dd HH:mm:ss`。

#### Scenario: 时间字段格式化输出
- **WHEN** 运单的 JoinTime 为 `2026-03-04 08:10:16`
- **THEN** Excel 中毛重时间列 SHALL 显示为 `2026-03-04 08:10:16`

#### Scenario: 时间字段为 null 时输出空
- **WHEN** 运单的 JoinTime 或 OutTime 为 null
- **THEN** 对应的时间列 SHALL 输出为空字符串

### Requirement: 固废发货/收货单位领域规则
系统 SHALL 在 `SolidWasteInfoExtensions` 中提供 `GetSolidWasteShippingAndReceivingUnits(this Waybill waybill, string providerName)` 静态扩展方法，封装发货/收货单位的确定规则。

#### Scenario: Waybill 收料模式
- **WHEN** `waybill.DeliveryType == DeliveryType.Receiving` 且 `providerName` 为 "长巷村"
- **THEN** 方法 SHALL 返回 `(ShippingUnit: "长巷村", ReceivingUnit: waybill.GetProperty<string>(ShipperKey) ?? DefaultShipper)`

#### Scenario: Waybill 发料模式
- **WHEN** `waybill.DeliveryType == DeliveryType.Sending` 且 `providerName` 为 "长巷村"
- **THEN** 方法 SHALL 返回 `(ShippingUnit: waybill.GetProperty<string>(ShipperKey) ?? DefaultShipper, ReceivingUnit: "长巷村")`

### Requirement: SolidWaste 扩展方法命名规范化
`SolidWasteInfoExtensions` 中所有方法 SHALL 使用 `SolidWaste` 前缀以确保模块边界清晰。`ISolidWasteInfo` 接口 SHALL 同步更新方法签名。

#### Scenario: Street 相关方法重命名
- **WHEN** 代码调用 `SetStreet` 或 `GetStreet`
- **THEN** 方法名 SHALL 分别为 `SetSolidWasteStreet` 和 `GetSolidWasteStreet`，行为不变

#### Scenario: Shipper 相关方法重命名
- **WHEN** 代码调用 `SetShipper` 或 `GetShipper`
- **THEN** 方法名 SHALL 分别为 `SetSolidWasteShipper` 和 `GetSolidWasteShipper`，行为不变

#### Scenario: SolidWasteService 私有方法命名规范化
- **WHEN** `SolidWasteService` 内部定义私有方法
- **THEN** 以下方法 SHALL 添加 `SolidWaste` 前缀：`QueryWaybillsAsync` → `SolidWasteQueryWaybillsAsync`，`BuildProviderDictAsync` → `SolidWasteBuildProviderDictAsync`，`BuildMaterialDictAsync` → `SolidWasteBuildMaterialDictAsync`，`MapToExportRow` → `SolidWasteMapToExportRow`

### Requirement: WeighingTicketDto 发货/收货单位使用领域规则
`WeighingMatchingService.CreateWeighingTicketDtoAsync` SHALL 调用 `GetSolidWasteShippingAndReceivingUnits` 领域方法来确定发货/收货单位，而非在 Service 层内联判断。

#### Scenario: 称重票据 DTO 使用领域方法
- **WHEN** `CreateWeighingTicketDtoAsync` 被调用并传入固废模式的 Waybill
- **THEN** 发货/收货单位 SHALL 通过 `waybill.GetSolidWasteShippingAndReceivingUnits(providerName)` 获取，而非 Service 层内联 if/else 判断

### Requirement: 固废小票毛皮净千克对齐 UI Displayed 吨
`WeighingMatchingService.CreateWeighingTicketDtoAsync` 在将运单吨重写入 `WeighingTicketDto` 的毛重/皮重/净重（千克）时，MUST 使用 `MaterialMath.ConvertDisplayedTonToKg`（先 Displayed 吨再换整数千克），使小票与有人值守固废 UI 的 `F2` 吨显示一致。

#### Scenario: 皮重打印千克与 UI 一致
- **WHEN** `OrderTruckWeight` 为 `6.045` 且 UI 显示 `6.05` 吨
- **THEN** 票据 DTO 皮重 MUST 为 `6050` 千克（而非 `6045`）

#### Scenario: 净重打印千克与 UI 一致
- **WHEN** `OrderGoodsWeight` 为 `6.995` 且 UI 显示 `7.00` 吨
- **THEN** 票据 DTO 净重 MUST 为 `7000` 千克（而非 `6995`）
