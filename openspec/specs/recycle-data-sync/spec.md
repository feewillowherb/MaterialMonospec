# Recycle Data Sync Service

## Purpose

定义 MaterialClient.Recycle 项目的数据同步服务，将本地称重记录同步到资源化利用厂管理系统，支持 HMAC-SHA256 签名认证和失败重试机制。

## Requirements

### Requirement: Recycle 同步服务扫描未同步记录
`RecycleDataSyncService` SHALL 定期查询 SQLite 中 `WeighingMode = Recycle` 且 `OrderType = Completed` 的 **Waybill**，且同步状态为待上报（未同步或 `FailCount < MaxFailCount`），对每个 Waybill **仅执行一次** §2.2 或 §2.3 上报。

#### Scenario: 已完成 Recycle 运单待上报
- **WHEN** `RecycleDataSyncService` 执行同步扫描
- **AND** 存在 `WeighingMode = Recycle` 且 `OrderType = Completed` 且未标记已同步的 Waybill
- **THEN** SHALL 获取这些 Waybill
- **AND** SHALL 对每个 Waybill 执行一次上报流程

#### Scenario: 未完成运单不扫描
- **WHEN** `RecycleDataSyncService` 执行同步扫描
- **AND** Waybill 的 `OrderType` 为 `FirstWeight` 或 `Esc`
- **THEN** SHALL NOT 上报该 Waybill

#### Scenario: 每个 Waybill 仅上报一次
- **WHEN** 同一 Waybill 关联进/出场两条 `WeighingRecord`
- **AND** Waybill 已完成
- **THEN** SHALL 仅产生 **一次** 市平台 POST（同一 `dataNo`）
- **AND** SHALL NOT 对两条 WeighingRecord 分别上报

#### Scenario: 非 Recycle 模式 Waybill 不扫描
- **WHEN** `RecycleDataSyncService` 执行同步扫描
- **AND** Waybill 的 `WeighingMode` 不为 `Recycle`
- **THEN** SHALL NOT 获取该 Waybill

### Requirement: WeighingRecord 到 RecycleTransportRecord 字段映射
`RecycleTransportRecord` 映射 SHALL 从关联 **Waybill** 取数；重量内部为 kg，§2.2 API 为吨（÷1000）；`DataNo` 为 `Waybill.OrderNo`；`ProductName` 为 `Material.Name`。

#### Scenario: 基本字段映射
- **WHEN** 已完成 Waybill（PlateNumber="浙A12345", OrderGoodsWeight=8500, OrderTruckWeight=3000, OrderTotalWeight=11500, OutTime=2026-07-08 14:30:00）被映射为 §2.2
- **THEN** `CarNo` SHALL 为 `"浙A12345"`
- **AND** `NetWeight` SHALL 为 `8.500`（吨）
- **AND** `TareWeight` SHALL 为 `3.000`（吨）
- **AND** `GrossWeight` SHALL 为 `11.500`（吨）
- **AND** `OutTime` SHALL 为 `"2026-07-08 14:30:00"`

#### Scenario: 重量为零或负值
- **WHEN** `Waybill.OrderGoodsWeight` 小于等于 0
- **THEN** 系统 SHALL NOT 上报该 Waybill（跳过并记录警告）

#### Scenario: DataNo 为 OrderNo
- **WHEN** `Waybill.OrderNo` 不为空
- **THEN** `DataNo` SHALL 为 `OrderNo` 的值
- **WHEN** `Waybill.OrderNo` 为空
- **THEN** SHALL NOT 上报（SHALL NOT 生成 `R-{id}` 回退）

#### Scenario: ProductName 来自 Material
- **WHEN** 字段映射执行
- **THEN** `ProductName` SHALL 为关联 `Material.Name`
- **AND** `PointNumber` SHALL 为 `RecycleSyncOptions.PointNumber`

### Requirement: 附件图片 Base64 编码
`RecycleDataSyncService` SHALL 读取 Waybill 关联附件并编码为 Base64（无 Data URL 前缀），多张英文逗号分隔。§2.2 `outPhotos` SHALL 聚合**进场侧**（`EntryPhoto`→`UnmatchedEntryPhoto`→`Lpr` 优先级）与**出场侧**（`ExitPhoto`）照片，进场侧在前、出场侧在后；§2.3 `inPhoto` SHALL 仅使用进场侧照片。

#### Scenario: §2.2 outPhotos 聚合进场与出场
- **WHEN** 已完成 `DeliveryType=Sending` 的 Waybill 同时存在 `EntryPhoto` 与 `ExitPhoto`
- **THEN** §2.2 `outPhotos` SHALL 同时包含进场侧与 `ExitPhoto` 的 Base64
- **AND** 进场侧照片 SHALL 排在 `ExitPhoto` 之前

#### Scenario: §2.3 inPhoto 仅进场侧
- **WHEN** 已完成 `DeliveryType=Receiving` 的 Waybill 同时存在进场侧与 `ExitPhoto`
- **THEN** §2.3 `inPhoto` SHALL 仅包含进场侧照片
- **AND** SHALL NOT 包含 `ExitPhoto`

#### Scenario: 多张图片逗号分隔
- **WHEN** Waybill 关联多张同侧 `AttachmentFile`
- **THEN** 照片字段 SHALL 为 `"base64_1,base64_2"` 格式
- **AND** SHALL NOT 包含空格或换行符

#### Scenario: 图片文件缺失
- **WHEN** `AttachmentFile.LocalPath` 对应文件不存在
- **THEN** SHALL 记录 `LogWarning`
- **AND** SHALL 跳过该图片（不中断同步流程）

### Requirement: 同步成功状态更新
`RecycleDataSyncService` SHALL 在接口返回 `Code == 200` 时将 `WeighingRecord.SyncStatus` 更新为 `SyncStatus.Synced`。

#### Scenario: 上报成功
- **WHEN** 接口返回 `{ "code": 200, "msg": "操作成功" }`
- **THEN** SHALL 将该记录 `SyncStatus` 设置为 `SyncStatus.Synced`
- **AND** SHALL 持久化到 SQLite

### Requirement: 同步失败重试与放弃
`RecycleDataSyncService` SHALL 在接口返回 `Code != 200` 时递增 `FailCount` 并记录 `FailMsg`；当 `FailCount >= MaxFailCount` 时 SHALL 将 `SyncStatus` 设置为 `SyncStatus.Failed`（放弃重试）。

#### Scenario: 可重试的失败
- **WHEN** 接口返回 `{ "code": 400, "msg": "参数错误" }`
- **AND** 当前 `FailCount` 为 0
- **AND** `MaxFailCount` 为 9
- **THEN** SHALL 将 `FailCount` 递增为 1
- **AND** SHALL 将 `FailMsg` 设置为 `"参数错误"`
- **AND** SHALL 保持 `SyncStatus` 为 `SyncStatus.Pending` 或 `SyncStatus.Failed`

#### Scenario: 达到最大失败次数放弃
- **WHEN** 接口返回错误
- **AND** 递增后 `FailCount >= MaxFailCount`
- **THEN** SHALL 将 `SyncStatus` 设置为 `SyncStatus.Failed`
- **AND** 该记录 SHALL NOT 在后续轮次中被扫描

#### Scenario: 网络异常不计 FailCount
- **WHEN** HTTP 请求抛出 `HttpRequestException`
- **THEN** SHALL 记录 `LogWarning` 日志
- **AND** SHALL NOT 递增 `FailCount`
- **AND** SHALL NOT 修改 `SyncStatus`
- **AND** 该记录 SHALL 在下次轮次中继续尝试

### Requirement: 同步服务轮询周期
`RecyclePollingBackgroundService` SHALL 以 `RecycleSync:PollIntervalSeconds` 配置的间隔执行同步扫描。

#### Scenario: 默认轮询间隔
- **WHEN** `RecycleSync:PollIntervalSeconds` 未配置
- **THEN** 轮询间隔 SHALL 为 5 秒

#### Scenario: 自定义轮询间隔
- **WHEN** `RecycleSync:PollIntervalSeconds` 配置为 10
- **THEN** 轮询间隔 SHALL 为 10 秒

### Requirement: 按 DeliveryType 分流 §2.2 与 §2.3
`RecycleDataSyncService` SHALL 根据 Waybill 的 `DeliveryType` 选择市平台端点：`Sending` → §2.2 `productTransportRecord`；`Receiving` → §2.3 `materialTransportRecord`。

#### Scenario: 发料走 §2.2
- **WHEN** 已完成 Waybill 的 `DeliveryType` 为 `Sending`
- **THEN** SHALL 调用 `SubmitTransportRecordAsync` 提交 `RecycleTransportRecord`

#### Scenario: 收料走 §2.3
- **WHEN** 已完成 Waybill 的 `DeliveryType` 为 `Receiving`
- **THEN** SHALL 调用 `SubmitMaterialTransportRecordAsync` 提交 `RecycleMaterialTransportRecord`

### Requirement: §2.3 收料重量单位为 kg
§2.3 映射 SHALL 将 `Waybill.OrderGoodsWeight`（kg）直接写入 `RecycleMaterialTransportRecord.NetWeight`，SHALL NOT 除以 1000。

#### Scenario: 收料净重 kg
- **WHEN** `Waybill.OrderGoodsWeight` 为 8500（kg）
- **AND** `DeliveryType` 为 `Receiving`
- **THEN** `NetWeight` SHALL 为 `8500`

### Requirement: Waybill 级同步状态
同步成功/失败状态 SHALL 持久化在 Waybill 的 ExtraProperties（或等价存储），SHALL NOT 依赖单条 WeighingRecord 的同步状态驱动 Waybill 上报去重。

#### Scenario: 上报成功后标记 Waybill
- **WHEN** 接口返回 `code == 200`
- **THEN** SHALL 将该 Waybill 标记为已同步
- **AND** 后续扫描 SHALL NOT 再次上报同一 Waybill

### Requirement: §2.2 接口对接规格
`RecycleDataSyncService` 上报 SHALL 符合 `docs/SyncDoc/杭州市资源化利用厂数据接入接口V1.0.md` §2.2 及 `_temp/resource-place-api-test` 联调脚本约定。

#### Scenario: 端点与方法
- **WHEN** 执行 §2.2 上报
- **THEN** SHALL POST 至 `/dataCenter/resourcePlace/productTransportRecord/v1/addBatch`
- **AND** 请求体最外层 SHALL 为 JSON Array
- **AND** Content-Type SHALL 为 `application/json`

#### Scenario: 成功判定
- **WHEN** 接口返回 `{ "code": 200, "msg": "操作成功" }`
- **THEN** SHALL 将该记录同步状态更新为成功

#### Scenario: HMAC 鉴权头
- **WHEN** 执行 §2.2 HTTP 请求
- **THEN** SHALL 经 `RecycleHmacDelegatingHandler` 注入 4 个 `X-AKZTJG-*` Header
- **AND** 签名字符串格式 SHALL 为 `{METHOD}\n{sorted_query}\n{accessKey}\n{GMT_date}\n`

### Requirement: 收货照片 TicketPhoto 采集
`RecycleDataSyncService` 在 §2.2 上报前 SHALL 读取 Waybill 关联的 `AttachType.TicketPhoto` 附件，编码为 Base64（无 Data URL 前缀），写入 §2.2 `receivingProof`。

#### Scenario: 存在收货照片
- **WHEN** Waybill 关联一张 `TicketPhoto` 附件且文件存在
- **THEN** `receivingProof` SHALL 为该附件 Base64
- **AND** SHALL 不带 Data URL 前缀

#### Scenario: 无收货照片
- **WHEN** Waybill 未关联 `TicketPhoto` 附件
- **THEN** `receivingProof` SHALL 为 null
- **AND** SHALL NOT 中断上报

#### Scenario: 收货照片文件缺失
- **WHEN** `TicketPhoto` 附件的 `LocalPath` 文件不存在
- **THEN** SHALL 记录 `LogWarning` 并跳过
- **AND** `receivingProof` SHALL 为 null

### Requirement: §2.2 扩展字段透传
`RecycleDataSyncService` 在构造 §2.2 `RecycleTransportRecord` 时 SHALL 透传 Recycle 录入的扩展字段：`UnitPrice`、`SaleContractNo` 来自 `Waybill`；`ReceivingTime` 来自 `Waybill.ReceivingTime`；`ConsigneeAddress` 来自关联 `Provider.Address`；`ReceivingProof` 来自 `TicketPhoto` 采集结果。

#### Scenario: 透传 Waybill 录入字段
- **WHEN** `Waybill.UnitPrice=120`、`Waybill.SaleContractNo="HT-001"`、`Waybill.ReceivingTime` 非空
- **THEN** 上报 payload 的 `unitPrice`/`saleContractNo`/`receivingTime` SHALL 分别取这些值

#### Scenario: 透传 Provider.Address
- **WHEN** 关联 `Provider.Address="杭州市西湖区某路 1 号"`
- **THEN** 上报 payload 的 `consigneeAddress` SHALL 为该值
- **WHEN** Provider 不存在或 Address 为空
- **THEN** `consigneeAddress` SHALL 为 null
