## MODIFIED Requirements

### Requirement: 客户端 SignalR 连接管理

MaterialClient MUST 提供 DeviceStatusSignalRClient 单例服务，负责管理与服务端的 SignalR 连接生命周期，包括启动、停止、状态监控、自动重连及连接恢复后的服务端登记触发。

#### Scenario: 客户端启动连接

- **假设** `appsettings.json` 配置了有效的 SignalR 服务端 URL
- **且** JWT Token 可用
- **WHEN** MaterialClient 应用启动时调用 `DeviceStatusSignalRClient.StartAsync()`
- **THEN** 客户端 SHALL 创建 HubConnection 实例
- **AND** 配置 JWT AccessTokenProvider
- **AND** 启动异步连接任务
- **AND** 连接成功后记录信息日志

#### Scenario: 客户端优雅停止连接

- **WHEN** MaterialClient 应用关闭时调用 `DeviceStatusSignalRClient.StopAsync()`
- **THEN** 客户端 SHALL 停止重连循环
- **AND** 主动断开 HubConnection
- **AND** 释放所有资源
- **AND** 不抛出未处理异常

#### Scenario: 连接状态监控

- **WHEN** HubConnection 连接状态发生变化
- **THEN** DeviceStatusSignalRClient SHALL 触发 `ConnectionStateChanged` 事件
- **AND** 事件参数包含新状态（Connecting、Connected、Disconnected、Reconnecting）
- **AND** 订阅方可通过事件获取实时连接状态

#### Scenario: 检测配置无效

- **假设** `appsettings.json` 中 SignalR 服务端 URL 为空或格式无效
- **WHEN** 调用 `DeviceStatusSignalRClient.StartAsync()`
- **THEN** 客户端 SHALL 抛出 `InvalidOperationException`
- **AND** 错误消息包含配置路径提示
- **AND** 记录错误日志

#### Scenario: 连接恢复后完成服务端客户端登记

- **WHEN** `OnConnectionRestoredAsync` 在连接建立或重连成功后被调用
- **THEN** SHALL 先刷新消息队列（`FlushMessageQueueAsync`）
- **AND** THEN SHALL 执行 `SyncProjectLicenseFromServerAsync`
- **AND** THEN SHALL 发布 `SignalRConnectionRestoredEventData` 触发设备状态重发
- **AND** SHALL 在授权同步完成后调用 `ISharedDeviceStatusTrackerRegistry.RepublishActiveStatuses()` 作为兜底
- **AND** 产生的 `UploadStatus` MUST 携带非空 `ProId`，以便服务端 `CacheClientConnectedAsync`

#### Scenario: 连接恢复登记不依赖 VerifyJwt  alone

- **WHEN** `VerifyJwtAsync` 与 `RegisterLogCapability` 已成功
- **AND** 尚未发送带 `ProId` 的 `UploadStatus`
- **THEN** 项目管理页 SHALL 仍将该客户端视为未登记（`GetClientListAsync` 无记录）
- **AND** 客户端 MUST 通过设备状态重发完成登记，不得假定 JWT 验签即等于已登记

### Requirement: 自动重连机制

客户端 MUST 实现指数退避重连策略，在网络中断或服务重启场景下自动恢复连接，并在重连成功后执行完整的 `OnConnectionRestoredAsync` 登记流程。

#### Scenario: 检测连接断开

- **WHEN** HubConnection 触发 `Closed` 事件
- **THEN** `DeviceStatusSignalRClient` SHALL 更新连接状态为 Disconnected
- **AND** 启动重连任务
- **AND** 记录警告日志

#### Scenario: 指数退避重连

- **假设** 连接已断开
- **WHEN** 重连任务执行
- **THEN** 客户端 SHALL 首次重连延迟 0 秒立即尝试
- **AND** 后续重连延迟按指数增长：0s、2s、10s、30s
- **AND** 最大延迟不超过 60 秒
- **AND** 每次重连前记录调试日志

#### Scenario: 重连成功

- **假设** 连接处于 Reconnecting 状态
- **WHEN** HubConnection 成功重新连接
- **THEN** 客户端 SHALL 更新连接状态为 Connected
- **AND** 清空重连计数器
- **AND** 发送缓存队列中的消息（如有）
- **AND** 执行 `OnConnectionRestoredAsync`（含授权同步后的设备状态重发与服务端登记）
- **AND** 记录信息日志

#### Scenario: 重连失败达到上限

- **假设** 连续重连失败 10 次
- **WHEN** 重连任务执行第 11 次尝试
- **THEN** 客户端 SHALL 停止自动重连
- **AND** 更新连接状态为 Disconnected
- **AND** 记录错误日志
