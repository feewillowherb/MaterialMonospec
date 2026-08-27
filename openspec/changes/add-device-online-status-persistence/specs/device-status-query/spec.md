## ADDED Requirements

### Requirement: 客户端连接列表与设备详情从数据库读取

`IDeviceStatusAppService.GetClientListAsync` MUST 从 `ClientOnlineStatus` 构建连接列表。`GetClientDevicesAsync` MUST 从设备在线详情当前态表构建结果。二者均不得仅依赖分布式缓存。

#### Scenario: 列表包含已离线实例

- **WHEN** 某 `(ProId, ClientId)` 曾连接后已断开，且缓存已清空
- **AND** 管理员调用 `GetClientListAsync`
- **THEN** 结果 SHALL 仍包含该实例
- **AND** `IsConnected` SHALL 为 false

#### Scenario: 同项目多实例连接列表

- **WHEN** 同一 `ProId` 下存在两个不同 `ClientId` 的连接态行
- **THEN** `GetClientListAsync` SHALL 返回可区分的两条（或等价结构）
- **AND** SHALL NOT 静默合并为单条而丢失 `ClientId`

#### Scenario: 设备详情读库

- **WHEN** 调用 `GetClientDevicesAsync(proId)` 且库中存在该 ProId 的设备详情行
- **THEN** 返回列表 SHALL 来自数据库当前态
- **AND** 每项 SHALL 包含 `DeviceType`、`Status`、`LastUpdateTime`
- **AND** 当存在多 `ClientId` 时每项 SHALL 包含 `ClientId`（或等价分组信息）

#### Scenario: 设备详情缓存为空仍可查

- **WHEN** `DeviceStatusCacheItem` 为空或不存在
- **AND** 数据库中仍有设备详情行
- **THEN** `GetClientDevicesAsync` SHALL 仍返回落库详情
- **AND** SHALL NOT 仅因缓存未命中而返回空列表

#### Scenario: 未注册判定

- **WHEN** 某项目 ProId 在 `ClientOnlineStatus` 中不存在任何行
- **THEN** 项目管理合并逻辑 SHALL 将该项目视为「未注册」
- **AND** 「离线」SHALL 表示至少有一行且全部 `IsConnected = false`
