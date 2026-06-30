## MODIFIED Requirements

### Requirement: Hub 连接生命周期缓存

DeviceStatusHub MUST 在客户端连接和断开时将连接元数据写入分布式缓存，并广播连接状态变更事件至浏览器端。

#### Scenario: 客户端连接时缓存连接元数据

- **WHEN** MaterialClient 向 DeviceStatusHub 发送首次带非空 `ProId` 的 `UploadStatus`
- **THEN** Hub SHALL 建立 ConnectionId → ProId 映射
- **AND** SHALL 将连接元数据写入缓存 `client_connection:{proId}`，包含 IsConnected=true、ConnectedAt=当前时间
- **AND** SHALL 将 ProId 注册到连接注册表缓存 `__connection_registry__`

#### Scenario: 客户端断开时更新断开时间

- **WHEN** MaterialClient 断开 DeviceStatusHub 连接（OnDisconnectedAsync）
- **THEN** Hub SHALL 更新缓存 `client_connection:{proId}` 中的 IsConnected=false、DisconnectedAt=当前时间
- **AND** SHALL 保留 ConnectedAt 不变（记录的是最近一次连接时间）

#### Scenario: 广播连接状态变更

- **WHEN** Hub 完成首次 `UploadStatus` 触发的连接登记或 OnDisconnectedAsync 中的断开更新
- **THEN** Hub SHALL 向 `client_connection` SignalR 组广播 `ClientConnectionUpdate` 事件
- **AND** 事件载荷 SHALL 包含 ProId、ProName、IsConnected、ConnectedAt、DisconnectedAt

#### Scenario: 浏览器订阅 client_connection 组

- **WHEN** 浏览器端调用 Hub 方法 `SubscribeClientConnection`
- **THEN** Hub SHALL 将该 ConnectionId 加入 `client_connection` 组
- **AND** 该连接 SHALL 能接收 `ClientConnectionUpdate` 广播
