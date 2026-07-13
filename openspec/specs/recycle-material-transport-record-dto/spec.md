# Recycle Material Transport Record DTO

## Purpose

定义 MaterialClient.Recycle 收料（§2.3）物料进场车次 DTO 与 Refit API，用于向市平台提交 `materialTransportRecord`。

## Requirements

### Requirement: RecycleMaterialTransportRecord 请求 DTO 定义
系统 SHALL 定义 `RecycleMaterialTransportRecord` 类，对齐市平台 §2.3 物料进场车次接口必填字段。

#### Scenario: DTO 必填字段
- **WHEN** `RecycleMaterialTransportRecord` 实例创建
- **THEN** SHALL 包含 `DataNo`、`PointNumber`、`CarNo`、`MaterialName`、`NetWeight`（kg）、`InTime`、`InPhoto`（Base64 逗号分隔）
- **AND** 可选字段 SHALL 包含 `DataStatus`、`CarrierCompanyName`、`TareWeight`、`GrossWeight`、`UnitPrice`、`PayAmount`

#### Scenario: JSON 字段名为 camelCase
- **WHEN** DTO 序列化为 JSON
- **THEN** 字段名 SHALL 使用 camelCase（如 `dataNo`、`materialName`、`inPhoto`）

### Requirement: IRecycleDataApi §2.3 端点
`IRecycleDataApi` SHALL 提供 §2.3 收料批量新增方法。

#### Scenario: SubmitMaterialTransportRecordAsync 方法签名
- **WHEN** `IRecycleDataApi` 被 Refit 代理调用
- **THEN** SHALL 提供 `SubmitMaterialTransportRecordAsync(List<RecycleMaterialTransportRecord> records, CancellationToken ct)`
- **AND** 该方法 SHALL 使用 `[Post("/dataCenter/resourcePlace/materialTransportRecord/v1/addBatch")]`
- **AND** SHALL 返回 `Task<RecycleApiResponse>`
- **AND** 请求 Body SHALL 为 JSON Array

### Requirement: FromWaybill 映射工厂方法
`RecycleMaterialTransportRecord` SHALL 提供从 `Waybill`（及关联数据）构造 DTO 的静态工厂方法，重量单位为 **kg**，时间格式 `yyyy-MM-dd HH:mm:ss`。

#### Scenario: 净重 kg 映射
- **WHEN** `Waybill.OrderGoodsWeight` 为 8500（kg）
- **THEN** `NetWeight` SHALL 为 `8500`（不向吨转换）

#### Scenario: 进场时间映射
- **WHEN** `Waybill.JoinTime` 为 `2026-07-09 10:00:00`
- **THEN** `InTime` SHALL 为 `"2026-07-09 10:00:00"`
