## Purpose

提供一次性同步服务，将本地创建的 Material 和 Provider 记录推送到服务端，获取服务端分配的 ID，并更新所有下游实体（Waybill、WeighingRecord、WaybillMaterial）的外键引用，使数据完全可追溯。

## Requirements

### Requirement: 同步服务读取所有本地 Material 和 Provider 记录
`MaterialProviderSyncService` SHALL 在同步操作开始时从本地数据库查询所有未删除的 `Material` 和 `Provider` 实体。

#### Scenario: 本地数据库包含材料和供应商记录
- **WHEN** 调用 `SyncAsync()` 且本地数据库包含 5 条 Material 记录和 3 条 Provider 记录
- **THEN** 服务将所有 5 条 Material 和 3 条 Provider 实体加载到内存中处理

#### Scenario: 本地数据库为空
- **WHEN** 调用 `SyncAsync()` 且不存在 Material 或 Provider 记录
- **THEN** 服务立即完成，输出日志消息提示无数据可同步，无错误返回

### Requirement: 同步服务将每条本地 Material 推送到服务端
服务 SHALL 对每条本地 Material 记录调用 `IMaterialPlatformApi.CreateMaterialByNameAsync`，以材料的 `Name`、`CoId` 和 `ProId` 作为请求体。

#### Scenario: 服务端成功创建材料
- **WHEN** 处理一条本地 Material，`Name="Concrete A"`、`CoId=1`、`ProId="proj-01"`
- **THEN** 服务向服务端发送 `CreateMaterialByNameInput(Name="Concrete A", CoId=1, ProId="proj-01")`，并将返回的 `GoodsId` 记录到本地→服务端 ID 映射中

#### Scenario: 服务端返回材料创建错误
- **WHEN** 服务端对 Material 创建请求返回非成功响应
- **THEN** 服务记录包含材料名称和本地 ID 的错误日志，并抛出异常以在任何数据库写入之前中止同步

#### Scenario: 本地材料 CoId 无效或 ProId 缺失
- **WHEN** 一条本地 Material 的 `CoId=0` 且 ProId 为 null
- **THEN** 服务记录警告并跳过该 Material，不尝试 API 调用

### Requirement: 同步服务将每条本地 Provider 推送到服务端
服务 SHALL 对每条本地 Provider 记录调用 `IMaterialPlatformApi.CreateProviderAsync`，以 `ProviderName`、`DeliveryType=0`、`CoId` 和 `ProId` 作为请求体。

#### Scenario: 服务端成功创建供应商
- **WHEN** 处理一条本地 Provider，`ProviderName="Supplier X"`、`CoId=1`、`ProId="proj-01"`
- **THEN** 服务向服务端发送 `CreateProviderInput(ProviderName="Supplier X", DeliveryType=0, CoId=1, ProId="proj-01")`，并将返回的 `ProviderId` 记录到本地→服务端 ID 映射中

#### Scenario: 服务端返回供应商创建错误
- **WHEN** 服务端对 Provider 创建请求返回非成功响应
- **THEN** 服务记录包含供应商名称和本地 ID 的错误日志，并抛出异常以在任何数据库写入之前中止同步

### Requirement: 同步服务用服务端返回的实体替换本地 Material 实体
所有 Material 推送完成后，服务 SHALL 删除所有本地 Material 实体，并使用 `MaterialGoodListResultDto.ToEntity()` 插入新实体，保留服务端分配的 `GoodsId` 作为主键。

#### Scenario: Material 实体被服务端数据替换
- **WHEN** 服务端已返回所有本地 Material 的 `MaterialGoodListResultDto` 响应
- **THEN** 本地 `Materials` DbSet 被清空，并通过 `ToEntity()` 转换重新填充，每个实体的 `Id` 等于服务端的 `GoodsId`

### Requirement: 同步服务用服务端返回的实体替换本地 Provider 实体
所有 Provider 推送完成后，服务 SHALL 删除所有本地 Provider 实体，并使用 `MaterialProviderListResultDto.ToEntity()` 插入新实体，保留服务端分配的 `ProviderId` 作为主键。因 `Address` 为本地专用字段（远端 DTO 不携带），服务 SHALL 在删表重建前按 `ProviderId` 快照本地 `Address`，重建后回填，SHALL NOT 丢失已录入的 `Address`。

#### Scenario: Provider 实体被服务端数据替换
- **WHEN** 服务端已返回所有本地 Provider 的 `MaterialProviderListResultDto` 响应
- **THEN** 本地 `Providers` DbSet 被清空，并通过 `ToEntity()` 转换重新填充，每个实体的 `Id` 等于服务端的 `ProviderId`

#### Scenario: 重建后保留本地 Address
- **WHEN** 本地 Provider（Id=200）已录入 `Address="杭州市西湖区某路 1 号"`，随后执行一次性同步重建
- **THEN** 重建后 Id=200 的 Provider `Address` SHALL 仍为 `"杭州市西湖区某路 1 号"`
- **AND** SHALL NOT 被远端 DTO 的空值覆盖为 null

### Requirement: 同步服务清空 MaterialUnit 和 MaterialType 表
在替换 Material/Provider 实体之后，服务 SHALL 清空 `MaterialUnit` 和 `MaterialType` 两张表的所有数据。

#### Scenario: MaterialUnit 表被清空
- **WHEN** Material/Provider 实体替换完成
- **THEN** `MaterialUnits` DbSet 中所有记录被删除（因 `MaterialId` 引用旧本地 ID，同步后失效）

#### Scenario: MaterialType 表被清空
- **WHEN** Material/Provider 实体替换完成
- **THEN** `MaterialTypes` DbSet 中所有记录被删除（本地分类数据需清除以便后续从服务端重新拉取）

#### Scenario: 清空操作在事务内执行
- **WHEN** Phase B 事务中执行清空操作后发生错误
- **THEN** 整个事务回滚，MaterialUnit 和 MaterialType 表恢复原状

### Requirement: 同步服务更新 Waybill 外键
服务 SHALL 使用本地→服务端 ID 映射更新每个 `Waybill` 实体的 `MaterialId` 和 `ProviderId`。

#### Scenario: Waybill 引用更新后的 Material 和 Provider ID
- **WHEN** 一条 Waybill 的 `MaterialId=1`（本地）和 `ProviderId=2`（本地），映射为 `1→100`、`2→200`
- **THEN** 该 Waybill 更新为 `MaterialId=100` 和 `ProviderId=200`

#### Scenario: Waybill 的 MaterialId 或 ProviderId 为 null
- **WHEN** 一条 Waybill 的 `MaterialId=null` 或 `ProviderId=null`
- **THEN** null FK 保持不变

### Requirement: 同步服务更新 WeighingRecord 外键
服务 SHALL 使用本地→服务端 Provider ID 映射更新每个 `WeighingRecord` 实体的 `ProviderId`。

#### Scenario: WeighingRecord 引用更新后的 Provider ID
- **WHEN** 一条 WeighingRecord 的 `ProviderId=2`（本地），映射为 `2→200`
- **THEN** 该 WeighingRecord 更新为 `ProviderId=200`

#### Scenario: WeighingRecord 的 ProviderId 为 null
- **WHEN** 一条 WeighingRecord 的 `ProviderId=null`
- **THEN** null FK 保持不变

### Requirement: 同步服务更新 WaybillMaterial 外键
服务 SHALL 使用本地→服务端 Material ID 映射更新每个 `WaybillMaterial` 实体的 `MaterialId`。

#### Scenario: WaybillMaterial 引用更新后的 Material ID
- **WHEN** 一条 WaybillMaterial 的 `MaterialId=1`（本地），映射为 `1→100`
- **THEN** 该 WaybillMaterial 更新为 `MaterialId=100`

### Requirement: 同步服务更新 WeighingRecord.MaterialsJson 中嵌套的 Material ID
服务 SHALL 反序列化每个 `WeighingRecord.MaterialsJson`，使用本地→服务端 Material ID 映射重写 `WeighingRecordMaterial.MaterialId` 值，然后将更新后的列表序列化回去。

#### Scenario: WeighingRecord 的 MaterialsJson 包含可映射的 Material ID
- **WHEN** 一条 WeighingRecord 的 `MaterialsJson` 包含一个 `WeighingRecordMaterial`，`MaterialId=1`（本地），映射为 `1→100`
- **THEN** `MaterialsJson` 更新后该项的 `MaterialId` 变为 `100`

#### Scenario: WeighingRecord 的 MaterialsJson 包含 null MaterialId
- **WHEN** `MaterialsJson` 中的一个 `WeighingRecordMaterial` 的 `MaterialId=null`
- **THEN** 该项的 `MaterialId` 保持不变（null）

#### Scenario: WeighingRecord 没有 MaterialsJson
- **WHEN** 一条 WeighingRecord 的 `MaterialsJson=null` 或为空
- **THEN** 跳过该记录，不做修改

### Requirement: 同步服务使用两阶段执行和分割的事务边界
服务 SHALL 将网络 I/O 与数据库写入分为两个阶段。Phase A（读取 + API 调用）不使用数据库事务执行。Phase B（实体替换 + FK 更新 + 验证）在单个 `IDbContextTransaction` 内执行。

#### Scenario: Phase A 期间 API 调用失败
- **WHEN** Phase A 期间第 3 次 Material API 调用因网络错误失败
- **THEN** 尚未进行任何数据库更改，无需事务回滚；服务抛出异常，包含已成功推送的记录详情

#### Scenario: Phase B 期间数据库写入失败
- **WHEN** Phase B 期间发生数据库写入错误
- **THEN** 事务回滚，数据库保持原始状态

#### Scenario: 同步成功后原子提交
- **WHEN** 所有 API 调用成功且所有 FK 更新已应用
- **THEN** Phase B 事务提交，持久化所有实体替换和 FK 重写

### Requirement: 同步服务在更新后验证引用完整性
FK 更新完成后，服务 SHALL 验证没有 `Waybill.MaterialId`、`Waybill.ProviderId`、`WeighingRecord.ProviderId`、`WaybillMaterial.MaterialId` 或 `WeighingRecord.MaterialsJson` 嵌套的 `MaterialId` 引用了不存在的本地 Material 或 Provider ID。

#### Scenario: 同步后所有 FK 引用有效
- **WHEN** 同步完成且所有 FK（包括 JSON 嵌套的）已重写
- **THEN** 服务查询孤立 FK 引用，记录零条警告

#### Scenario: 检测到孤立 FK 引用
- **WHEN** 一条 WaybillMaterial 的 `MaterialId` 不匹配任何现有 Material `Id`
- **THEN** 服务记录警告，包含孤立实体的 ID 和 FK 值，然后完成

### Requirement: 同步服务通过 ABP 约定注册
`MaterialProviderSyncService` SHALL 实现 `ITransientDependency` 并使用 `[AutoConstructor]` 进行自动依赖注入，与项目约定保持一致。

#### Scenario: 从 DI 容器解析服务
- **WHEN** 一个类从 ABP 服务提供者请求 `IMaterialProviderSyncService`
- **THEN** `MaterialProviderSyncService` 被解析，`IMaterialPlatformApi` 和 `MaterialClientDbContext` 通过构造函数注入

### Requirement: 同步服务暴露无参数的异步入口点
服务 SHALL 提供 `Task SyncAsync(CancellationToken cancellationToken = default)` 方法，执行完整流水线，无需调用方提供参数。

#### Scenario: 调用方无参数调用 SyncAsync
- **WHEN** 以默认参数调用 `SyncAsync()`
- **THEN** 完整的四阶段流水线（读取、推送、更新、验证）执行至完成

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

#### Scenario: Provider 管理页展示与可操作编辑 Address
- **WHEN** 打开 `ProviderManagementWindow`
- **THEN** DataGrid SHALL 展示 `Address` 列
- **AND** DataGrid SHALL 提供"操作"列，列内每行 SHALL 包含"编辑"按钮
- **AND** 点击"编辑"按钮 SHALL 打开 `ProviderEditWindow`，预填该行供应商数据（含 `Address`）
- **AND** 用户在 `ProviderEditWindow` 修改字段（名称/联系人/电话/收货地址）并确认后，SHALL 调用 `ProviderService.UpdateProviderAsync` 持久化（`Address` 作为本地专用字段更新；远端契约不新增 Address）
- **AND** 保存成功后 `ProviderManagementWindow` SHALL 刷新列表以反映最新数据
- **AND** 用户取消编辑（点击"取消"/关闭窗口）SHALL NOT 调用 `UpdateProviderAsync`

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
