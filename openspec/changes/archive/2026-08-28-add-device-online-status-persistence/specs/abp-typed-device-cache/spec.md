## ADDED Requirements

### Requirement: 连接态与设备详情缓存降级为写穿旁路

客户端连接态的权威数据源 MUST 为 `ClientOnlineStatus`（`(ProId, ClientId)`）。设备在线详情的权威数据源 MUST 为设备详情当前态表（`(ProId, ClientId, DeviceType)`）。`ClientConnectionCacheItem` / `DeviceStatusCacheItem` 仅可作为写穿旁路；查询 MUST NOT 仅依赖缓存命中。

#### Scenario: 连接写入同时落库

- **WHEN** 某客户端实例连接或断开需要更新连接态
- **THEN** `DeviceStatusService` MUST 持久化对应 `(ProId, ClientId)` 的 `ClientOnlineStatus`
- **AND** MAY 同步更新写穿缓存（键 MUST 能区分 `ClientId`，不得仅用 ProId 作为唯一键覆盖同项目其它实例）
- **AND** 缓存更新失败 MUST NOT 导致跳过数据库写入

#### Scenario: 设备详情写入同时落库

- **WHEN** `UploadStatus` 更新某设备类型状态
- **THEN** `DeviceStatusService` MUST upsert 对应 `(ProId, ClientId, DeviceType)` 的设备详情当前态
- **AND** MAY 同时写入 `DeviceStatusCacheItem` 消息队列作旁路
- **AND** 缓存失败 MUST NOT 跳过数据库 upsert

#### Scenario: GetClientList / GetClientDevices 不以缓存为唯一来源

- **WHEN** `GetClientListAsync` 或 `GetClientDevicesAsync` 被调用
- **THEN** MUST 从数据库构建结果
- **AND** MUST NOT 仅因连接注册表或 `DeviceStatusCacheItem` 为空而在库中仍有数据时返回空列表

## MODIFIED Requirements

### Requirement: DeviceStatusService 类型化缓存注入

`DeviceStatusService` MUST 注入类型化 `IDistributedCache<T>` 实例替代原始 `IDistributedCache`。MUST NOT 注入 `IDistributedCache<ConnectionRegistryCacheItem>`。设备消息队列仍使用类型化缓存；客户端连接态权威源为数据库（见 `device-online-status-persistence`），粒度 `(ProId, ClientId)`。

#### Scenario: 注入 3 个类型化缓存实例

- **WHEN** `DeviceStatusService` 被 DI 容器构造
- **THEN** MUST 注入 `IDistributedCache<DeviceStatusCacheItem>` 用于设备消息队列缓存
- **AND** MUST 注入 `IDistributedCache<ClientRegistryCacheItem>` 用于客户端发现注册表和连接发现注册表（使用不同缓存键）
- **AND** MUST 注入 `IDistributedCache<ClientConnectionCacheItem>` 用于连接状态写穿旁路缓存
- **AND** MUST NOT 注入原始 `IDistributedCache`
- **AND** MUST NOT 注入 `IDistributedCache<ConnectionRegistryCacheItem>`

#### Scenario: 连接注册表使用 ClientRegistryCacheItem

- **WHEN** `DeviceStatusService` 需要读写连接发现注册表
- **THEN** MUST 通过 `IDistributedCache<ClientRegistryCacheItem>` 使用缓存键 `"__connection_registry__"` 读写
- **AND** MUST NOT 使用 `ConnectionRegistryCacheItem` 类型

#### Scenario: 设备状态消息缓存写入

- **WHEN** `DeviceStatusService` 缓存一条新的设备状态消息
- **THEN** MUST 通过 `IDistributedCache<DeviceStatusCacheItem>.GetAsync(proId)` 读取现有队列
- **AND** MUST 将新消息追加到 `Messages` 列表
- **AND** MUST 在 `Messages.Count` 超过 100 时移除最早的条目（FIFO）
- **AND** MUST 通过 `IDistributedCache<DeviceStatusCacheItem>.SetAsync(proId, updatedItem)` 写回缓存
- **AND** MUST NOT 手动调用 `JsonSerializer.Serialize` 或 `JsonSerializer.Deserialize`

#### Scenario: 设备状态消息缓存读取

- **WHEN** `GetCachedMessagesAsync(clientId)` 被调用
- **THEN** MUST 通过 `IDistributedCache<DeviceStatusCacheItem>.GetAsync(key)` 读取缓存项
- **AND** 若缓存不存在 MUST 返回空列表

#### Scenario: 设备状态消息缓存清除

- **WHEN** `ClearCachedMessagesAsync(clientId)` 被调用
- **THEN** MUST 通过 `IDistributedCache<DeviceStatusCacheItem>.RemoveAsync(key)` 移除缓存项

#### Scenario: 客户端注册表更新

- **WHEN** 新的客户端 ProId 需要注册到客户端发现注册表
- **THEN** MUST 读取 `ClientRegistryCacheItem`（缓存键 `"__registry__"`），将 ProId 加入 `ProIds` 集合
- **AND** 仅在 ProId 为新增时写回缓存

#### Scenario: 连接状态缓存写入

- **WHEN** 客户端实例连接或断开时
- **THEN** MUST 持久化对应 `(ProId, ClientId)` 的 `ClientOnlineStatus`
- **AND** MAY 通过写穿更新 `ClientConnectionCacheItem`（或等价实例级缓存项）
- **AND** 连接时 MUST 设置 `IsConnected = true`、`ConnectedAt` 为写路径时钟
- **AND** 断开时 MUST 设置 `IsConnected = false`、`DisconnectedAt` 为写路径时钟
- **AND** MUST NOT 因单个 `ClientId` 断开而将同 `ProId` 下其它实例在数据库中标为离线

#### Scenario: 连接状态缓存读取

- **WHEN** 查询某实例或某项目的连接态
- **THEN** MUST 优先从数据库 `ClientOnlineStatus` 读取
- **AND** 若不存在 MUST 返回空/未注册语义
- **AND** MAY 使用缓存仅作加速，且结果 MUST 与数据库一致或在未命中时回源数据库
