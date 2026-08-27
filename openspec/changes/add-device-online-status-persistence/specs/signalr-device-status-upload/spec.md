## ADDED Requirements

### Requirement: 连接态落库于 SignalR 生命周期

DeviceStatusHub / DeviceStatusService 在客户端实例上线与断线时 MUST 将连接态按 `(ProId, ClientId)` 持久化到 `ClientOnlineStatus`，不得仅写入内存字典或分布式缓存，不得按 ProId 单行覆盖同项目其它实例。

#### Scenario: 首次映射写库为在线

- **WHEN** `UploadStatus` 携带非空 `ProId` 与非空 `ClientId` 且该连接完成映射
- **THEN** 服务端 SHALL upsert 该 `(ProId, ClientId)` 为 `IsConnected = true`
- **AND** SHALL 设置 `ConnectedAt` / `LastSeenAt`
- **AND** SHALL 保留同 `ProId` 下其它 `ClientId` 行不变

#### Scenario: UploadStatus 写设备在线详情

- **WHEN** 合法的 `UploadStatus` 含 `ProId`、`ClientId`、`DeviceType`、`Status`
- **THEN** 服务端 SHALL upsert 设备在线详情当前态行 `(ProId, ClientId, DeviceType)`
- **AND** SHALL 继续广播既有 `DeviceStatusUpdate`（若实现需要）

#### Scenario: 断开写库为离线

- **WHEN** 已映射 `(ProId, ClientId)` 的连接触发 `OnDisconnectedAsync`
- **THEN** 服务端 SHALL 仅将该实例连接态 upsert 为 `IsConnected = false`
- **AND** SHALL 将该实例下全部设备详情行标为 Offline
- **AND** SHALL 设置 `DisconnectedAt` / 更新相关时间戳
- **AND** SHALL NOT 将同项目其它仍在线实例的连接态或设备详情标为离线

## MODIFIED Requirements

### Requirement: 连接生命周期管理

服务端 MUST 管理客户端连接生命周期，跟踪连接/断开事件，支持连接元数据查询，并将每个客户端实例的在线/离线状态按 `(ProId, ClientId)` 持久化到数据库。

#### Scenario: 记录客户端连接

- **WHEN** 客户端成功连接至 DeviceStatusHub
- **THEN** Hub SHALL 调用 OnConnectedAsync() 方法
- **AND** 提取 ConnectionId 和 ClientId
- **AND** 记录信息日志（包含 IP 地址、User Agent）
- **AND** 可选地将连接信息存入内存字典

#### Scenario: 处理客户端断开

- **WHEN** 客户端连接断开（正常关闭或超时）
- **THEN** Hub SHALL 调用 OnDisconnectedAsync() 方法
- **AND** 记录信息日志（包含异常原因）
- **AND** 从内存字典中移除连接信息
- **AND** 若该连接已映射 `(ProId, ClientId)`，SHALL 仅将对应 `ClientOnlineStatus` 更新为离线
- **AND** 广播既有客户端连接更新事件至其他订阅方

#### Scenario: 查询在线客户端

- **WHEN** 管理员查询客户端连接列表
- **THEN** 系统 SHALL 以数据库 `ClientOnlineStatus` 为权威来源返回实例级连接信息
- **AND** 包含 ProId、ClientId、连接/断开时间、是否在线
- **AND** 同一 ProId 下可返回多条
- **AND** 不包含敏感信息如 JWT Token
