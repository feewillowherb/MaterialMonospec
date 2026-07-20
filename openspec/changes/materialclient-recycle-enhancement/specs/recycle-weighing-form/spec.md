# Recycle Weighing Form

## ADDED Requirements

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
