## MODIFIED Requirements

### Requirement: Provider 本地 Address 字段
`Provider` 实体 SHALL 维护可空 `Address` 列（string?），作为 §2.2 `consigneeAddress` 的数据源。`Address` SHALL 为本地专用字段，SHALL NOT 进入远端 `CreateProviderInput`/`UpdateProviderInput`/`MaterialProviderListResultDto` 契约。`Address` 在所有场景（含 Recycle 内联新建供应商）均 SHALL 为可选可空，任何表单层 SHALL NOT 对其强制必填。

#### Scenario: Address 列可空
- **WHEN** 非 Recycle 场景创建 Provider
- **THEN** `Address` SHALL 允许为 null
- **AND** 数据库列 SHALL 为 nullable

#### Scenario: Recycle 内联新建供应商 Address 可选可空
- **WHEN** 在 Recycle 称重详情通过选择器内联新建供应商（`CreateNewProviderAsync`）
- **THEN** 表单 SHALL 允许用户填写或留空 `Address`
- **AND** SHALL NOT 对 `Address` 强制必填
- **AND** 用户留空时 `Address` SHALL 落库为 null

#### Scenario: 远端创建后回填本地 Address
- **WHEN** `ProviderService.CreateProviderAsync` 携带非空 `Address` 调用
- **THEN** SHALL 先调用远端 `CreateProvider`（不传 Address）
- **AND** SHALL 在本地 upsert 前将 `Address` 写入返回的 Provider 实体

#### Scenario: 远端创建后不回填空 Address
- **WHEN** `ProviderService.CreateProviderAsync` 携带空或 null `Address` 调用
- **THEN** SHALL 跳过 Address 回填，Provider 实体 `Address` SHALL 保持 null

#### Scenario: ProviderDto 与分页查询携带 Address
- **WHEN** `ProviderService.GetPagedProvidersAsync` 执行分页投影
- **THEN** `ProviderDto` SHALL 携带 `Address`
- **AND** 选择器与管理页 SHALL 能读取该值

#### Scenario: Provider 管理页展示与编辑 Address
- **WHEN** 打开 `ProviderEditWindow`/`ProviderManagementWindow`
- **THEN** SHALL 展示 `Address` 字段
- **AND** SHALL 允许编辑（编辑结果落本地；是否同步远端遵循既有 `UpdateProvider` 约定，远端契约不新增 Address）

## ADDED Requirements

### Requirement: Recycle 内联新建供应商表单可选录入 Address
Recycle / SolidWaste 称重详情页通过供应商选择器内联新建供应商时，系统 SHALL 提供包含"供应商名称"与"收货地址"两个字段的新建表单。供应商名称 SHALL 必填（沿用 `ProviderService.CreateProviderAsync` 对 `providerName` 的非空校验），收货地址 SHALL 可选可空、无任何必填或格式校验。该表单 SHALL 与"新增材料"流程（`ConfirmTextDialog`）相互独立，互不影响。

#### Scenario: 新建供应商表单包含名称与地址两个输入框
- **WHEN** 用户在供应商选择器中触发"新增"并通过 `CreateNewProviderAsync` 打开新建供应商表单
- **THEN** 表单 SHALL 同时显示"供应商名称"输入框与"收货地址"输入框
- **AND** 名称输入框 SHALL 预填选择器中已输入的搜索文本作为初始名称
- **AND** 地址输入框 SHALL 初始为空

#### Scenario: 用户填写地址后创建
- **WHEN** 用户在新建供应商表单中输入名称="测试供应商"、地址="某市某区某路 1 号"并确认
- **THEN** 系统 SHALL 调用 `ProviderService.CreateProviderAsync("测试供应商", deliveryType, "某市某区某路 1 号")`
- **AND** 创建成功后返回的 `Provider.Address` SHALL 为"某市某区某路 1 号"

#### Scenario: 用户留空地址后创建
- **WHEN** 用户在新建供应商表单中输入名称="测试供应商"、地址留空并确认
- **THEN** 系统 SHALL 调用 `ProviderService.CreateProviderAsync("测试供应商", deliveryType, null)`
- **AND** 创建成功后返回的 `Provider.Address` SHALL 为 null

#### Scenario: 地址不做必填校验
- **WHEN** 用户在新建供应商表单中地址留空并点击确认
- **THEN** 表单 SHALL NOT 阻止确认
- **AND** SHALL NOT 显示地址必填错误提示

#### Scenario: 名称为空时阻止创建
- **WHEN** 用户在新建供应商表单中名称留空或仅含空白字符并点击确认
- **THEN** 表单 SHALL 阻止确认（或在调用 Service 后由 `ProviderService.CreateProviderAsync` 抛出 `ArgumentException`）
- **AND** SHALL 提示供应商名称必填

#### Scenario: 取消新建供应商
- **WHEN** 用户在新建供应商表单中点击"取消"、按 ESC 或关闭窗口
- **THEN** `CreateNewProviderAsync` SHALL 返回 null
- **AND** SHALL NOT 调用 `ProviderService.CreateProviderAsync`

#### Scenario: 新增材料流程不受影响
- **WHEN** 用户通过材料选择器触发"新增材料"打开 `ConfirmTextDialog`
- **THEN** `ConfirmTextDialog` SHALL 仍为单输入框（仅名称）形态
- **AND** SHALL NOT 显示收货地址输入框
