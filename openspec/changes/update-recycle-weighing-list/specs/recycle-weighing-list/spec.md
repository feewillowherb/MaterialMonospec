## ADDED Requirements

### Requirement: 回收列表使用本机行

回收称重主界面 SHALL 用回收自己的列表行展示 `WeighingMode.Recycle` 的称重记录。列表 SHALL NOT 使用城管列表行、`IsAnomaly`、`AnomalyReason` 或城管进出类型。上传状态 SHALL 使用与城管相同的 `SyncStatus` 字段。

#### Scenario: 打开称重列表

- **WHEN** 操作员打开全部或正常页签
- **THEN** 每一行来自一条回收称重记录
- **AND** 行包含车牌、重量、收发、抓拍时间、上传时间和平台接收状态

#### Scenario: 异常与通行页签

- **WHEN** 操作员打开异常、卡口或成品页签
- **THEN** 列表为空

### Requirement: 列表字段取自称重记录

车牌、重量、收发、抓拍时间、车牌颜色和车型 SHALL 取自称重记录上的对应值。收发 SHALL 使用 `DeliveryType`：收料为「收」，发料为「发」。空车牌、空收发、空颜色或空车型 SHALL 显示「—」。重量 SHALL 使用记录上的吨。

#### Scenario: 收料称重

- **WHEN** 记录的收发类型为收料且车牌和重量已保存
- **THEN** 列表显示该车牌、该吨数和「收」
- **AND** 抓拍时间等于记录的 `AddDate`

### Requirement: 上传时间与接收状态

列表 SHALL 把平台接收确认时间显示为 `UploadTime`。确认成功时客户端 SHALL 保存该时刻，且不覆盖已保存的时刻。无确认时刻时上传时间 SHALL 显示「—」。回收称重 SHALL 用 `RecycleSyncStatus` 保存与城管相同的状态名：`Pending` 与 `Synced`。旧键 `RecycleWebReceiveState` 的 `Accepted` SHALL 仍按 `Synced` 读取。显示文字与 `SyncStatus` 的说明一致：null 为「—」，`Pending` 为「待上传」，`Synced` 为「已同步」。

#### Scenario: 尚未进入待上传

- **WHEN** 记录没有平台接收状态
- **THEN** `SyncStatus` 为 null，状态为「—」，上传时间为「—」

#### Scenario: 等待平台确认

- **WHEN** 记录的平台接收状态为待上传
- **THEN** `SyncStatus` 为 `Pending`，状态为「待上传」，上传时间为「—」

#### Scenario: 平台已确认

- **WHEN** 平台接收被确认
- **THEN** `SyncStatus` 为 `Synced`，状态为「已同步」
- **AND** 上传时间等于本次确认保存的时刻
