# Recycle Weighing Form

## Purpose

定义 Recycle 模式独立称重表单视图与 DataTemplate，以及完成校验相对 SolidWaste 的差异。

## Requirements

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

### Requirement: Recycle 表单新增单价与合同号输入
`RecycleModeFormView` SHALL 新增 `unitPrice`（单价，元/吨）与 `saleContractNo`（销售合同编号）两个输入控件，与既有字段（称重类型、车牌号、供应商、材料名称、备注）风格一致（Grid 列宽 72、FontSize 12）。两值经 `RecycleWeighingDetailViewModel` 双向绑定，随保存/完成流程透传。

#### Scenario: 表单展示单价与合同号输入
- **WHEN** `RecycleModeFormView` 渲染
- **THEN** SHALL 包含「单价」与「合同编号」两个输入控件
- **AND** 控件 SHALL 绑定到 ViewModel 的 `UnitPrice`/`SaleContractNo` 响应式属性

#### Scenario: 打开既有 Waybill 回填单价与合同号
- **WHEN** Recycle 详情打开已保存的 Waybill
- **THEN** `UnitPrice` SHALL 回填自 `Waybill.UnitPrice`
- **AND** `SaleContractNo` SHALL 回填自 `Waybill.SaleContractNo`

#### Scenario: 单价与合同号随保存透传
- **WHEN** 用户填写单价 `120`、合同号 `HT-001` 并保存
- **THEN** ViewModel SHALL 将两值放入 `UpdateRecycleModeInput`
- **AND** SHALL 调用 `IRecycleWeighingService.UpdateRecycleModeAsync` 持久化

#### Scenario: 单价与合同号为可选
- **WHEN** 用户未填写单价或合同号即保存
- **THEN** 保存 SHALL 成功（两字段可选）
- **AND** 对应 Waybill 列 SHALL 为 null
