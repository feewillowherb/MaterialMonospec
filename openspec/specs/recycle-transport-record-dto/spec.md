# Recycle Transport Record DTO

## Purpose

定义 MaterialClient.Recycle 项目的数据传输对象（DTO）和 Refit API 接口，用于与资源化利用厂管理系统进行称重记录数据交换。

## Requirements

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
  - `OutPhotos` (string, 必填) — 进场+出场照片 Base64（不带标识头，逗号分隔，进场在前出场在后）
  - `SaleContractNo` (string?, 可选) — 销售合同编号
  - `Consignee` (string?, 可选) — 收货方
  - `ConsigneeAddress` (string?, 可选) — 收货地址
  - `ReceivingTime` (string?, 可选) — 收货时间，格式 `yyyy-MM-dd HH:mm:ss`
  - `ReceivingProof` (string?, 可选) — 收货照片 Base64

#### Scenario: OutPhotos 携带进场与出场照片
- **WHEN** Waybill 同时关联进场侧与出场侧（`ExitPhoto`）附件
- **THEN** `OutPhotos` SHALL 先列进场侧照片 Base64、再列出场侧照片 Base64
- **AND** 多张 SHALL 以英文逗号分隔，不带空格或 Data URL 前缀

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

### Requirement: RecycleApiResponse 响应 DTO 定义
系统 SHALL 定义 `RecycleApiResponse` 类，用于解析接口的响应。

#### Scenario: 响应字段定义
- **WHEN** `RecycleApiResponse` 实例创建
- **THEN** SHALL 包含以下属性：
  - `Code` (int) — 状态码
  - `Msg` (string?) — 错误描述
  - `Data` (object?) — 信息结构

#### Scenario: 成功响应解析
- **WHEN** 接口返回 JSON `{ "code": 200, "msg": "操作成功", "data": null }`
- **THEN** `RecycleApiResponse.Code` SHALL 为 `200`
- **AND** `RecycleApiResponse.Msg` SHALL 为 `"操作成功"`

### Requirement: IRecycleDataApi Refit 接口定义
系统 SHALL 定义 `IRecycleDataApi` Refit 接口，对接端点。

#### Scenario: SubmitTransportRecordAsync 方法签名
- **WHEN** `IRecycleDataApi` 被 Refit 代理调用
- **THEN** SHALL 提供 `SubmitTransportRecordAsync(List<RecycleTransportRecord> records, CancellationToken ct)` 方法
- **AND** 该方法 SHALL 使用 `[Post("/dataCenter/resourcePlace/productTransportRecord/v1/addBatch")]` 特性
- **AND** SHALL 返回 `Task<RecycleApiResponse>`
- **AND** 请求 Body SHALL 为 JSON Array（`List<RecycleTransportRecord>` 的 JSON 序列化结果）

#### Scenario: 请求体为 JSON Array
- **WHEN** 调用 `SubmitTransportRecordAsync` 传入包含 1 条记录的列表
- **THEN** HTTP 请求 Body SHALL 为 `[{"dataNo":"...","pointNumber":"...","carNo":"..."}]`（JSON Array 格式）
- **AND** Content-Type SHALL 为 `application/json`

### Requirement: FromWaybill §2.2 补充字段映射
`RecycleTransportRecord.FromWaybill` SHALL 在既有映射（`DataNo`/`ProductName`/`CarrierCompanyName`/重量/`OutTime`/`OutPhotos`）基础上，补齐 §2.2 接口未填字段的数据来源；这些字段均来自 Waybill 关联数据或 Recycle 录入。

#### Scenario: 单价来自 Waybill
- **WHEN** `Waybill.UnitPrice` 为 `120.0`
- **THEN** `UnitPrice` SHALL 为 `120.0`
- **WHEN** `Waybill.UnitPrice` 为 null
- **THEN** `UnitPrice` SHALL 为 null（不上报该可选字段）

#### Scenario: 销售合同号来自 Waybill
- **WHEN** `Waybill.SaleContractNo` 为 `"HT-2026-0001"`
- **THEN** `SaleContractNo` SHALL 为 `"HT-2026-0001"`
- **WHEN** `Waybill.SaleContractNo` 为空
- **THEN** `SaleContractNo` SHALL 为 null

#### Scenario: 收货时间来自 Waybill
- **WHEN** `Waybill.ReceivingTime` 为 `2026-07-09 15:20:00`
- **THEN** `ReceivingTime` SHALL 为 `"2026-07-09 15:20:00"`
- **WHEN** `Waybill.ReceivingTime` 为 null
- **THEN** `ReceivingTime` SHALL 为 null

#### Scenario: 收货地址来自 Provider.Address
- **WHEN** `Waybill.ProviderId` 关联 `Provider.Address` 为 `"杭州市西湖区某路 1 号"`
- **THEN** `ConsigneeAddress` SHALL 为 `"杭州市西湖区某路 1 号"`
- **WHEN** 关联 Provider 不存在或 `Address` 为空
- **THEN** `ConsigneeAddress` SHALL 为 null

#### Scenario: 收货照片来自 TicketPhoto 附件
- **WHEN** Waybill 关联 `AttachType.TicketPhoto` 附件且文件存在
- **THEN** `ReceivingProof` SHALL 为该附件的 Base64（不带 Data URL 前缀）
- **WHEN** Waybill 未关联 `TicketPhoto` 附件
- **THEN** `ReceivingProof` SHALL 为 null
