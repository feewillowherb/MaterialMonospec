## MODIFIED Requirements

### Requirement: RecycleTransportRecord 请求 DTO 定义
系统 SHALL 定义 `RecycleTransportRecord` 类，包含接口要求的全部字段。

#### Scenario: DTO 字段完整性
- **WHEN** `RecycleTransportRecord` 实例创建
- **THEN** SHALL 包含以下属性：
  - `DataNo` (string, 必填) — 数据唯一标识
  - `DataStatus` (int?, 可选) — 数据状态，默认 0
  - `PointNumber` (string, 必填) — 资源化利用厂唯一标识
  - `CarNo` (string, 必填) — 车牌号
  - `CarrierCompanyName` (string?, 可选) — 公司名称
  - `ProductName` (string, 必填) — 成品名称
  - `NetWeight` (decimal, 必填) — 净重（吨）
  - `TareWeight` (decimal?, 可选) — 皮重（吨）
  - `GrossWeight` (decimal?, 可选) — 毛重（吨）
  - `UnitPrice` (decimal?, 可选) — 单价（元/吨）
  - `PayAmount` (decimal?, 可选) — 结算金额（元）
  - `OutTime` (string, 必填) — 出场时间，格式 `yyyy-MM-dd HH:mm:ss`
  - `OutPhotos` (string, 必填) — 进场照片 Base64（不带标识头，逗号分隔）
  - `SaleContractNo` (string?, 可选) — 销售合同编号
  - `Consignee` (string?, 可选) — 收货方
  - `ConsigneeAddress` (string?, 可选) — 收货地址
  - `ReceivingTime` (string?, 可选) — 收货时间
  - `ReceivingProof` (string?, 可选) — 收货照片 Base64

### Requirement: FromWeighingRecord 字段映射规则
`RecycleTransportRecord.FromWeighingRecord`（或等价 Mapper）SHALL 从关联 `Waybill` 映射 §2.2 字段；`DataNo` SHALL 为 `Waybill.OrderNo`；`ProductName` SHALL 来自 `Material.Name`；`CarrierCompanyName` SHALL 来自 `Provider.ProviderName`。

#### Scenario: DataNo 使用 OrderNo
- **WHEN** 关联 `Waybill.OrderNo` 为 `"fl-20260709103000-0001"`
- **THEN** `DataNo` SHALL 为 `"fl-20260709103000-0001"`
- **AND** SHALL NOT 使用 `R-{recordId}` 回退

#### Scenario: OrderNo 缺失时跳过映射
- **WHEN** 关联 Waybill 的 `OrderNo` 为空或 null
- **THEN** 系统 SHALL NOT 构造可上报的 `RecycleTransportRecord`
- **AND** SHALL 记录警告日志

#### Scenario: ProductName 来自 Material.Name
- **WHEN** Waybill 关联材料的 `Material.Name` 为 `"成品灰土"`
- **THEN** `ProductName` SHALL 为 `"成品灰土"`
- **AND** SHALL NOT 读取 `RecycleSyncOptions.ProductName` 配置

#### Scenario: CarrierCompanyName 来自 Provider
- **WHEN** `Waybill.ProviderId` 关联 `Provider.ProviderName` 为 `"测试运输公司"`
- **THEN** `CarrierCompanyName` SHALL 为 `"测试运输公司"`

#### Scenario: 重量 kg 转吨
- **WHEN** `Waybill.OrderGoodsWeight` 为 8500（kg）
- **THEN** `NetWeight` SHALL 为 `8.500`（吨）
