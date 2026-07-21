# Recycle Data Sync Service

## MODIFIED Requirements

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

## ADDED Requirements

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
