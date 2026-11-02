## MODIFIED Requirements

### Requirement: 标准模式运单分页查询
系统 SHALL 提供标准模式运单的分页查询能力，查询 `WeighingMode == Standard` 的 Waybill 记录，并关联 Material 和 Provider 表获取商品名称和供应商名称（**包含软删除主数据行**）。

#### Scenario: 按筛选条件查询标准模式运单
- **WHEN** ViewModel 执行分页查询
- **THEN** 系统 SHALL 查询 `WeighingMode == Standard` 且未删除（`IsDeleted == false`）的 Waybill 记录
- **AND** SHALL 解析 Material 获取 MaterialName（含 `Material.IsDeleted == true` 的行）
- **AND** SHALL 解析 Provider 获取 ProviderName（含 `Provider.IsDeleted == true` 的行）
- **AND** SHALL 支持按 PlateNumber、DeliveryType、OrderType、日期范围（JoinTime）、MaterialName 筛选
- **AND** 当按 MaterialName 筛选时，名称匹配 SHALL 包含已软删 Material
- **AND** SHALL 按 JoinTime 降序排列
- **AND** SHALL 返回 TotalCount 和分页后的 Items

#### Scenario: 分页参数
- **WHEN** ViewModel 请求第 N 页数据
- **THEN** 系统 SHALL 使用 Skip((N-1) * PageSize).Take(PageSize) 进行分页
- **AND** PageSize SHALL 为 10

### Requirement: StandardExportRow 数据映射
系统 SHALL 将 Waybill 实体映射为 StandardExportRow DTO，字段映射关系如下：

| StandardExportRow 属性 | 来源 |
|------------------------|------|
| PlateNumber | Waybill.PlateNumber |
| DeliveryType | Waybill.DeliveryType（显示为"收料"或"发料"） |
| MaterialName | Material.Name（按 MaterialId 解析，含软删） |
| OrderType | Waybill.OrderType（显示为"首称中"/"已完成"/"已取消"） |
| PlanQuantity | Waybill.OrderPlanOnPcs |
| PlanWeight | Waybill.OrderPlanOnWeight |
| OffsetCount | Waybill.OffsetCount |
| ActualQuantity | Waybill.OrderPcs |
| ActualWeight | Waybill.OrderGoodsWeight |
| UnitConversion | Waybill.MaterialUnitRate |
| JoinTime | Waybill.JoinTime（格式化为 yyyy-MM-dd HH:mm:ss） |
| OutTime | Waybill.OutTime（格式化为 yyyy-MM-dd HH:mm:ss） |
| ProviderName | Provider.ProviderName（按 ProviderId 解析，含软删） |
| OrderNo | Waybill.OrderNo |
| Remark | Waybill.Remark |

#### Scenario: 正确映射所有字段
- **WHEN** 查询返回 Waybill 记录列表
- **THEN** 每个 Waybill SHALL 被映射为 StandardExportRow
- **AND** 所有字符串字段 SHALL 处理 null 值（返回空字符串）
- **AND** 所有数值字段 SHALL 处理 null 值（返回 null 或 0）
- **AND** 时间字段 SHALL 格式化为 "yyyy-MM-dd HH:mm:ss" 字符串

#### Scenario: 主数据硬缺失时的处理
- **WHEN** Waybill 的 MaterialId 或 ProviderId 在对应表中不存在任何行
- **THEN** MaterialName SHALL 返回空字符串
- **AND** ProviderName SHALL 返回空字符串

#### Scenario: 主数据仅软删除时仍映射名称
- **WHEN** Waybill 的 MaterialId 或 ProviderId 指向存在且 `IsDeleted == true` 的主数据
- **THEN** MaterialName / ProviderName SHALL 分别为该实体的名称字段
