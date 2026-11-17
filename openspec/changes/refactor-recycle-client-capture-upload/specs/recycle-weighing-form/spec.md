## MODIFIED Requirements

### Requirement: RecycleModeFormView 独立表单
系统 SHALL 为 `WeighingMode.Recycle` 提供独立表单视图 `RecycleModeFormView`，布局风格与既有 Attended 明细一致，作为**采集**表单：SHALL 包含车牌号；SHALL NOT 包含供应商/发货单位/收货单位、材料名称、单价、销售合同编号录入控件。

#### Scenario: Recycle 详情区显示独立表单
- **WHEN** Recycle 客户端打开运单或称重记录详情
- **AND** 当前 `WeighingMode` 为 `Recycle`
- **THEN** 详情区 SHALL 渲染 `RecycleModeFormView`
- **AND** SHALL NOT 渲染 `SolidWasteModeFormView`

#### Scenario: 采集字段不含业务主数据
- **WHEN** `RecycleModeFormView` 显示
- **THEN** SHALL 包含车牌号
- **AND** SHALL NOT 显示供应商选择、材料选择、单价或合同编号输入

### Requirement: Recycle 完成校验不含 SolidWaste 专用字段
`RecycleWeighingDetailViewModel` 完成运单时 SHALL 校验车牌号规范与毛重有效；SHALL NOT 要求供应商、材料、联单编号、所属镇街、类型选择、单价或销售合同号。

#### Scenario: 无供应商材料仍可完成
- **WHEN** 用户在 Recycle 模式点击完成
- **AND** 车牌合法且毛重有效
- **AND** 未选供应商与材料
- **THEN** 完成操作 SHALL 成功

#### Scenario: 无联单仍可完成
- **WHEN** 用户在 Recycle 模式点击完成
- **AND** 未填联单编号、镇街、类型
- **THEN** 完成操作 SHALL 成功（不受 SolidWaste 字段约束）

## REMOVED Requirements

### Requirement: Recycle 表单新增单价与合同号输入
**Reason**: 业务表单改到 Web 运输清单；工控不再采集单价与销售合同号。
**Migration**: 单价/合同在 `UrbanManagement.XiaoShanResource` 运输清单补全；删除 `RecycleModeFormView` 对应控件与 VM 绑定。
