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
  - `OutPhotos` (string, 必填) — 出场照片 Base64（不带标识头，逗号分隔）
  - `SaleContractNo` (string?, 可选) — 销售合同编号
  - `Consignee` (string?, 可选) — 收货方
  - `ConsigneeAddress` (string?, 可选) — 收货地址
  - `ReceivingTime` (string?, 可选) — 收货时间
  - `ReceivingProof` (string?, 可选) — 收货照片 Base64

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
