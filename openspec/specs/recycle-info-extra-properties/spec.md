# Recycle Info Extra Properties

## Purpose

定义 Recycle 模式下，WeighingRecord 在成为 Waybill 前暂存业务字段（单价、合同号）到 ExtraProperties 的机制，以及匹配建单时将它们拷贝到 RecycleWaybillExtension 的规则。

## Requirements

### Requirement: RecycleInfoExtensions 类型安全读写 WeighingRecord ExtraProperties
系统 SHALL 提供 `RecycleInfoExtensions`（参考 `SolidWasteInfoExtensions`），通过 ABP `SetProperty`/`GetProperty` 在 `WeighingRecord.ExtraProperties` 中读写 Recycle 运单前暂存字段。键名 SHALL 为 `RecycleInfo.UnitPrice`（`decimal?`）与 `RecycleInfo.SaleContractNo`（`string?`）。SHALL NOT 在 Waybill ExtraProperties 上使用同名键（Waybill 侧字段仍存 `RecycleWaybillExtension`）。

#### Scenario: 写入与读取单价
- **WHEN** 对 `WeighingRecord` 调用 `SetUnitPrice(120m)` 后调用 `GetUnitPrice()`
- **THEN** SHALL 返回 `120`
- **AND** ExtraProperties 键 SHALL 为 `RecycleInfo.UnitPrice`

#### Scenario: 写入与读取合同号
- **WHEN** 对 `WeighingRecord` 调用 `SetSaleContractNo("HT-001")` 后调用 `GetSaleContractNo()`
- **THEN** SHALL 返回 `"HT-001"`
- **AND** ExtraProperties 键 SHALL 为 `RecycleInfo.SaleContractNo`

#### Scenario: null 置空
- **WHEN** 对已有值的记录调用 `SetUnitPrice(null)` 与 `SetSaleContractNo(null)`
- **THEN** 对应 `Get*` SHALL 返回 null

#### Scenario: 批量设置
- **WHEN** 调用 `SetRecycleInfo(unitPrice, saleContractNo)`
- **THEN** SHALL 等价于分别设置两字段

### Requirement: 匹配建单拷贝 RecycleInfo 到 RecycleWaybillExtension
`WeighingMatchingService.CreateWaybillAsync` 在创建 Recycle 模式 Waybill 时 SHALL 将关联 `WeighingRecord` 的 Recycle ExtraProperties 拷贝到新建 Waybill 的 `RecycleWaybillExtension`（upsert `UnitPrice`/`SaleContractNo`）。拷贝优先级 SHALL 为 join 记录优先、缺失则 fallback 到 out 记录（对齐 `CopySolidWasteInfoToWaybill`）。SHALL NOT 在此步骤写入 `ReceivingTime`。

#### Scenario: join 记录有 RecycleInfo 时建单写入扩展表
- **WHEN** 匹配创建 Waybill 且 join `WeighingRecord` 的 ExtraProperties 含 `UnitPrice=120`、`SaleContractNo="HT-001"`
- **THEN** SHALL 存在按该 Waybill Id 关联的 `RecycleWaybillExtension`
- **AND** 其 `UnitPrice` SHALL 为 `120`、`SaleContractNo` SHALL 为 `"HT-001"`
- **AND** `ReceivingTime` SHALL 为 null

#### Scenario: join 无值时 fallback 到 out 记录
- **WHEN** join 记录无 RecycleInfo 值且 out 记录有 `UnitPrice=80`
- **THEN** 新建扩展行的 `UnitPrice` SHALL 为 `80`

#### Scenario: 两侧均无 RecycleInfo
- **WHEN** join 与 out 记录均无 RecycleInfo 值
- **THEN** SHALL NOT 强制插入空扩展行，或插入后两字段均为 null（实现二选一，行为须可测且稳定）

#### Scenario: 非 Recycle 模式建单
- **WHEN** 建单时 `WeighingMode` 不是 Recycle
- **THEN** SHALL NOT 因本需求写入 `RecycleWaybillExtension`