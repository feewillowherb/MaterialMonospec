## ADDED Requirements

### Requirement: 市平台同步默认关闭
`RecycleSync:Enabled` 默认 SHALL 为 `false`。当为 `false` 时，系统 SHALL NOT 扫描或向市平台 §2.2/§2.3 提交运单；产品主路径为上传我方平台。

#### Scenario: 默认配置不启市同步
- **WHEN** 使用产品默认配置启动 Recycle 客户端
- **THEN** `RecycleSync:Enabled` SHALL 为 false
- **AND** SHALL NOT 启动 `RecyclePollingBackgroundService` 市平台上报循环

#### Scenario: 显式开启才扫描市平台
- **WHEN** 运维将 `RecycleSync:Enabled` 设为 true（非产品默认）
- **THEN** 既有市平台同步实现可运行
- **AND** 此路径 SHALL NOT 作为本 change 验收的主路径

## MODIFIED Requirements

### Requirement: Recycle 同步服务扫描未同步记录
仅当 `RecycleSync:Enabled` 为 true 时，`RecycleDataSyncService` SHALL 定期查询 SQLite 中 `WeighingMode = Recycle` 且 `OrderType = Completed` 的 **Waybill**，且同步状态为待上报，对每个 Waybill **仅执行一次** §2.2 或 §2.3 上报。当 Enabled 为 false 时 SHALL NOT 执行该扫描。

#### Scenario: Enabled 为 false 不扫描
- **WHEN** `RecycleSync:Enabled` 为 false
- **AND** 存在已完成未同步 Waybill
- **THEN** `RecycleDataSyncService` SHALL NOT 向市平台 POST

#### Scenario: 已完成 Recycle 运单待上报（仅 Enabled）
- **WHEN** `RecycleSync:Enabled` 为 true
- **AND** `RecycleDataSyncService` 执行同步扫描
- **AND** 存在 `WeighingMode = Recycle` 且 `OrderType = Completed` 且未标记已同步的 Waybill
- **THEN** SHALL 获取这些 Waybill
- **AND** SHALL 对每个 Waybill 执行一次上报流程
