## MODIFIED Requirements

### Requirement: Recycle 同步服务扫描未同步记录
`RecycleDataSyncService` SHALL 定期查询 SQLite 中 `WeighingMode = Recycle` 且同步状态为待上报（`SyncStatus = Pending` 或 `SyncStatus = Failed` 且 `FailCount < MaxFailCount`）的 `WeighingRecord` 记录，进行 §2.2 数据上报。

#### Scenario: 存在 Recycle 模式未同步记录
- **WHEN** `RecycleDataSyncService` 执行同步扫描
- **AND** 数据库中存在 `WeighingMode = Recycle` 且 `SyncStatus = Pending` 的 `WeighingRecord`
- **THEN** SHALL 获取这些记录
- **AND** SHALL 对每条记录执行 §2.2 上报流程

#### Scenario: 非 Recycle 模式记录不扫描
- **WHEN** `RecycleDataSyncService` 执行同步扫描
- **AND** 数据库中存在 `WeighingMode = SolidWaste` 或 `WeighingMode = Standard` 的记录
- **THEN** SHALL NOT 获取这些记录进行 §2.2 上报

#### Scenario: 无未同步记录
- **WHEN** `RecycleDataSyncService` 执行同步扫描
- **AND** 数据库中无符合条件的 Recycle 记录
- **THEN** SHALL 跳过本轮同步

#### Scenario: 超过最大失败次数的记录不扫描
- **WHEN** `RecycleDataSyncService` 执行同步扫描
- **AND** 数据库中存在 `WeighingMode = Recycle` 且 `FailCount >= MaxFailCount` 的记录
- **THEN** SHALL NOT 获取这些记录

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
