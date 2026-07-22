## MODIFIED Requirements

### Requirement: Provider 本地 Address 字段
`Provider` 实体 SHALL 新增可空 `Address` 列（string?），作为 §2.2 `consigneeAddress` 的数据源。`Address` SHALL 为本地专用字段，SHALL NOT 进入远端 `CreateProviderInput`/`UpdateProviderInput`/`MaterialProviderListResultDto` 契约。

#### Scenario: Address 列可空
- **WHEN** 非 Recycle 场景创建 Provider
- **THEN** `Address` SHALL 允许为 null
- **AND** 数据库列 SHALL 为 nullable

#### Scenario: Recycle 内联新建供应商校验 Address 必填
- **WHEN** 在 Recycle 称重详情通过选择器内联新建供应商（`CreateNewProviderAsync`）
- **THEN** 表单 SHALL 校验 `Address` 必填
- **AND** 缺失时 SHALL 阻止创建并提示

#### Scenario: 远端创建后回填本地 Address
- **WHEN** `ProviderService.CreateProviderAsync` 携带 `Address` 调用
- **THEN** SHALL 先调用远端 `CreateProvider`（不传 Address）
- **AND** SHALL 在本地 upsert 前将 `Address` 写入返回的 Provider 实体

#### Scenario: ProviderDto 与分页查询携带 Address
- **WHEN** `ProviderService.GetPagedProvidersAsync` 执行分页投影
- **THEN** `ProviderDto` SHALL 携带 `Address`
- **AND** 选择器与管理页 SHALL 能读取该值

#### Scenario: Provider 管理页展示与可操作编辑 Address
- **WHEN** 打开 `ProviderManagementWindow`
- **THEN** DataGrid SHALL 展示 `Address` 列
- **AND** DataGrid SHALL 提供"操作"列，列内每行 SHALL 包含"编辑"按钮
- **AND** 点击"编辑"按钮 SHALL 打开 `ProviderEditWindow`，预填该行供应商数据（含 `Address`）
- **AND** 用户在 `ProviderEditWindow` 修改字段（名称/联系人/电话/收货地址）并确认后，SHALL 调用 `ProviderService.UpdateProviderAsync` 持久化（`Address` 作为本地专用字段更新；远端契约不新增 Address）
- **AND** 保存成功后 `ProviderManagementWindow` SHALL 刷新列表以反映最新数据
- **AND** 用户取消编辑（点击"取消"/关闭窗口）SHALL NOT 调用 `UpdateProviderAsync`

## ADDED Requirements

### Requirement: Provider 管理页编辑入口可触发
`ProviderManagementWindow` 的 DataGrid 操作列"编辑"按钮 SHALL 通过 `{Binding DataContext.EditCommand, ElementName=Root}` 绑定到 `ProviderManagementViewModel.EditCommand`，并以 `{Binding}` 将当前行 `ProviderDto` 作为命令参数。Recycle 与 AttendedWeighing 模式 SHALL 共享同一 `ProviderManagementWindow`，因此编辑能力 SHALL 对两种模式同时生效。

#### Scenario: 点击编辑按钮打开编辑窗口
- **WHEN** 用户在 `ProviderManagementWindow` DataGrid 中点击某行的"编辑"按钮
- **THEN** 系统 SHALL 以该行 `ProviderDto` 为参数触发 `EditCommand`
- **AND** SHALL 打开 `ProviderEditWindow`，4 个字段（名称/联系人/电话/收货地址）SHALL 预填该行数据
- **AND** 焦点 SHALL 落在可编辑字段上

#### Scenario: 编辑保存后刷新列表
- **WHEN** 用户在 `ProviderEditWindow` 修改字段并点击"确定"，`UpdateProviderAsync` 返回成功
- **THEN** `ProviderEditWindow` SHALL 关闭并返回更新后的 `ProviderDto`
- **AND** `ProviderManagementViewModel` SHALL 重新调用 `LoadDataAsync` 刷新列表
- **AND** 列表中对应行 SHALL 显示更新后的字段值

#### Scenario: 编辑取消不触发保存
- **WHEN** 用户在 `ProviderEditWindow` 点击"取消"或关闭窗口
- **THEN** 窗口 SHALL 关闭并返回 null
- **AND** `ProviderManagementViewModel` SHALL NOT 调用 `LoadDataAsync`（列表保持不变）
- **AND** SHALL NOT 调用 `UpdateProviderAsync`

#### Scenario: 编辑入口对 Recycle 模式生效
- **WHEN** Recycle 应用启动并通过 `AttendedWeighingWindow` 的"数据管理→供应管理"打开 `ProviderManagementWindow`
- **THEN** 该窗口 SHALL 与 AttendedWeighing 模式呈现完全相同的编辑能力（操作列 + 编辑按钮）

#### Scenario: 编辑入口在空列表时不可见
- **WHEN** `ProviderManagementWindow` 查询结果为空（无供应商记录）
- **THEN** DataGrid SHALL 无数据行
- **AND** SHALL 不展示任何"编辑"按钮（无行可操作）
