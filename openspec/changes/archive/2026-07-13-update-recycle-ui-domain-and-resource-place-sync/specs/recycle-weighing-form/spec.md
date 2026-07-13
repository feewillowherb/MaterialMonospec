## ADDED Requirements

### Requirement: RecycleModeFormView 独立表单
系统 SHALL 为 `WeighingMode.Recycle` 提供独立表单视图 `RecycleModeFormView`，布局与 `SolidWasteModeFormView` 一致（Grid 列宽 72、Spacing 6、顶边色 `#B0EBFF`），但不包含联单编号、所属镇街、类型选择三行。

#### Scenario: Recycle 详情区显示独立表单
- **WHEN** Recycle 客户端打开运单或称重记录详情
- **AND** 当前 `WeighingMode` 为 `Recycle`
- **THEN** 详情区 SHALL 渲染 `RecycleModeFormView`
- **AND** SHALL NOT 渲染 `SolidWasteModeFormView`

#### Scenario: 保留字段与 SolidWaste 一致
- **WHEN** `RecycleModeFormView` 显示
- **THEN** SHALL 包含称重类型、车牌号、供应商/发货单位/收货单位、材料名称、备注字段
- **AND** 供应商标签 SHALL 随 `DeliveryType` 切换

### Requirement: Recycle 表单 DataTemplate 注册
`AttendedWeighingDetailView` SHALL 为 `RecycleWeighingDetailViewModel` 注册 DataTemplate，映射至 `RecycleModeFormView`。

#### Scenario: ViewModel 类型匹配模板
- **WHEN** 详情区 `DataContext` 为 `RecycleWeighingDetailViewModel`
- **THEN** Avalonia SHALL 自动选择 `RecycleModeFormView` 模板

### Requirement: Recycle 完成校验不含 SolidWaste 专用字段
`RecycleWeighingDetailViewModel` 完成运单时 SHALL 校验供应商与材料必填，SHALL NOT 要求联单编号、所属镇街或类型选择。

#### Scenario: 无联单仍可完成
- **WHEN** 用户在 Recycle 模式点击完成
- **AND** 已填供应商与材料
- **AND** 未填联单编号、镇街、类型
- **THEN** 完成操作 SHALL 成功
