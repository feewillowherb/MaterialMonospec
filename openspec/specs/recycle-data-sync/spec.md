# Recycle Data Sync Service

## Purpose

定义 MaterialClient.Recycle 项目的数据同步服务，将本地称重记录同步到资源化利用厂管理系统，支持 HMAC-SHA256 签名认证和失败重试机制。

## Requirements

### Requirement: Recycle 同步服务扫描未同步记录
`RecycleDataSyncService` SHALL 定期查询 SQLite 中 `SyncStatus = Pending` 或 `SyncStatus = Failed` 且 `FailCount < MaxFailCount` 的 `WeighingRecord` 记录，进行数据上报。

#### Scenario: 存在未同步记录
- **WHEN** `RecycleDataSyncService` 执行同步扫描
- **AND** 数据库中存在 `SyncStatus = Pending` 的 `WeighingRecord`
- **THEN** SHALL 获取所有未同步记录
- **AND** SHALL 对每条记录执行上报流程

#### Scenario: 无未同步记录
- **WHEN** `RecycleDataSyncService` 执行同步扫描
- **AND** 数据库中无 `SyncStatus = Pending` 且 `FailCount < MaxFailCount` 的记录
- **THEN** SHALL 跳过本轮同步

#### Scenario: 超过最大失败次数的记录不扫描
- **WHEN** `RecycleDataSyncService` 执行同步扫描
- **AND** 数据库中存在 `FailCount >= MaxFailCount` 的记录
- **THEN** SHALL NOT 获取这些记录

### Requirement: WeighingRecord 到 RecycleTransportRecord 字段映射
`RecycleWeightMapper` SHALL 将 `WeighingRecord` 实体映射为 `RecycleTransportRecord` DTO，遵循接口字段要求。

#### Scenario: 基本字段映射
- **WHEN** 一个 `WeighingRecord`（TruckNo="浙A12345", OrderGoodsWeight=8500, OrderTruckWeight=3000, OrderTotalWeight=11500, OutTime=2026-07-08 14:30:00）被映射
- **THEN** `RecycleTransportRecord.CarNo` SHALL 为 `"浙A12345"`
- **AND** `RecycleTransportRecord.NetWeight` SHALL 为 `8.500`（8500÷1000，吨）
- **AND** `RecycleTransportRecord.TareWeight` SHALL 为 `3.000`（3000÷1000，吨）
- **AND** `RecycleTransportRecord.GrossWeight` SHALL 为 `11.500`（11500÷1000，吨）
- **AND** `RecycleTransportRecord.OutTime` SHALL 为 `"2026-07-08 14:30:00"`

#### Scenario: 重量为零或负值
- **WHEN** `WeighingRecord.OrderGoodsWeight` 小于等于 0
- **THEN** `RecycleTransportRecord.NetWeight` SHALL 为 `0`
- **AND** 系统 SHALL NOT 上报该记录（跳过或标记失败）

#### Scenario: DataNo 生成
- **WHEN** `WeighingRecord.OrderNo` 不为 null
- **THEN** `RecycleTransportRecord.DataNo` SHALL 为 `OrderNo` 的值
- **WHEN** `WeighingRecord.OrderNo` 为 null
- **THEN** `RecycleTransportRecord.DataNo` SHALL 由系统生成唯一标识

#### Scenario: 配置字段填充
- **WHEN** 字段映射执行
- **THEN** `RecycleTransportRecord.PointNumber` SHALL 为 `RecycleSyncOptions.PointNumber` 的值
- **AND** `RecycleTransportRecord.ProductName` SHALL 为 `RecycleSyncOptions.ProductName` 的值

### Requirement: 附件图片 Base64 编码
`RecycleDataSyncService` SHALL 读取 `WeighingRecord` 关联的 `AttachmentFile`（AttachType = LprCapturePhoto），将图片文件编码为 Base64 字符串，不带 `data:image/jpeg;base64,` 标识头，多张图片用英文逗号分隔。

#### Scenario: 单张图片编码
- **WHEN** 一条 `WeighingRecord` 关联 1 张 `AttachmentFile`（LocalPath="photos/cap001.jpg"）
- **THEN** SHALL 读取 `PathManager.ToAbsolutePath("photos/cap001.jpg")` 对应的文件字节
- **AND** SHALL 使用 `Convert.ToBase64String()` 编码
- **AND** `outPhotos` SHALL 为纯 Base64 字符串（无标识头）

#### Scenario: 多张图片逗号分隔
- **WHEN** 一条 `WeighingRecord` 关联 2 张 `AttachmentFile`
- **THEN** `outPhotos` SHALL 为 `"base64_1,base64_2"` 格式
- **AND** SHALL NOT 包含空格或换行符

#### Scenario: 图片文件缺失
- **WHEN** `AttachmentFile.LocalPath` 对应的绝对路径文件不存在
- **THEN** SHALL 记录 `LogWarning` 日志
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
