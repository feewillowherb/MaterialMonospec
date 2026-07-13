## MODIFIED Requirements

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
`RecycleDataSyncService` SHALL 读取 Waybill 关联附件中 **进场侧** 类型（`EntryPhoto`、`UnmatchedEntryPhoto`、`Lpr`，按此优先级），编码为 Base64（无 Data URL 前缀），多张英文逗号分隔，写入 §2.2 `outPhotos` 或 §2.3 `inPhoto`。

#### Scenario: 进场侧附件优先
- **WHEN** Waybill 同时存在 `EntryPhoto` 与 `ExitPhoto`
- **THEN** SHALL 使用 `EntryPhoto`（或 `UnmatchedEntryPhoto`、`Lpr`）作为 API 照片来源
- **AND** SHALL NOT 使用 `ExitPhoto` 作为 §2.2/§2.3 上报来源

#### Scenario: 多张图片逗号分隔
- **WHEN** Waybill 关联 2 张进场侧 `AttachmentFile`
- **THEN** 照片字段 SHALL 为 `"base64_1,base64_2"` 格式
- **AND** SHALL NOT 包含空格或换行符

#### Scenario: 图片文件缺失
- **WHEN** `AttachmentFile.LocalPath` 对应文件不存在
- **THEN** SHALL 记录 `LogWarning`
- **AND** SHALL 跳过该图片（不中断同步流程）

## ADDED Requirements

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
