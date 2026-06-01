# SignalR Device Status Upload Specification

## Purpose

定义桌面端（MaterialClient）与服务端（UrbanManagement）之间基于 SignalR 的设备状态实时上传能力，涵盖连接管理、状态上报、消息协议、错误处理、重连机制等技术要求。

## Requirements

### Requirement: 服务端 SignalR Hub 端点注册

UrbanManagement 应用必须提供 DeviceStatusHub SignalR 端点，支持客户端通过 WebSocket 连接并进行设备状态消息交互。

#### Scenario: Hub 端点可访问

- **WHEN** 客户端向 `http://server/hubs/devicestatus` 发起 WebSocket 连接请求
- **THEN** UrbanManagement 应用 SHALL 接受连接请求
- **AND** 返回 SignalR 连接协商响应
- **AND** HTTP 状态码为 200

#### Scenario: Hub 支持 JWT 认证

- **WHEN** 客户端连接请求包含有效的 JWT Bearer Token
- **THEN** DeviceStatusHub SHALL 验证 Token 有效性
- **AND** 连接成功建立
- **AND** Hub Context 中包含已认证用户信息

#### Scenario: Hub 拒绝无效认证

- **WHEN** 客户端连接请求不包含 JWT Token 或 Token 已过期
- **THEN** DeviceStatusHub SHALL 拒绝连接请求
- **AND** 返回 401 Unauthorized 错误
- **AND** 记录安全警告日志

#### Scenario: Hub 配置 CORS 策略

- **WHEN** UrbanManagement 应用启动
- **THEN** SignalR SHALL 配置 CORS 策略允许桌面端域名
- **AND** 允许的来源通过 `SignalR:AllowedOrigins` 配置
- **AND** 默认允许 `localhost` 和本机 IP

### Requirement: 客户端 SignalR 连接管理

MaterialClient 必须提供 DeviceStatusSignalRClient 单例服务，负责管理与服务端的 SignalR 连接生命周期，包括启动、停止、状态监控和自动重连。

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

### Requirement: 设备状态消息协议

系统必须定义统一的设备状态消息格式，包含客户端标识、设备类型、状态值、时间戳等核心字段，并使用 JSON 序列化。

#### Scenario: 消息格式定义

- **WHEN** 构建设备状态消息
- **THEN** 消息必须为 `DeviceStatusMessage` record 类型
- **AND** 包含 `ClientId` 字段（string，客户端唯一标识）
- **AND** 包含 `DeviceType` 字段（string，设备类型如 "Scale"、"Camera"、"LPR"、"Sound"）
- **AND** 包含 `Status` 字段（string，状态值如 "Online"、"Offline"）
- **AND** 包含 `Timestamp` 字段（DateTime，状态变化时间）
- **AND** 包含 `AdditionalData` 字段（string? nullable，可选附加信息）

#### Scenario: 消息序列化

- **WHEN** `DeviceStatusMessage` 实例需要通过 SignalR 发送
- **THEN** 系统 SHALL 使用 System.Text.Json 序列化
- **AND** 使用 `CamelCase` 命名策略（驼峰命名）
- **AND** 忽略 null 值字段
- **AND** 序列化结果为合法 JSON 字符串

#### Scenario: 消息反序列化

- **WHEN** 服务端接收 JSON 格式的设备状态消息
- **THEN** 系统 SHALL 反序列化为 `DeviceStatusMessage` 实例
- **AND** 验证所有必需字段非空
- **AND** 时间戳字段正确解析为 DateTime
- **AND** 反序列化失败时抛出 `JsonException`

#### Scenario: 消息验证

- **WHEN** 服务端接收到设备状态消息
- **THEN** 系统 SHALL 验证 `ClientId` 长度不超过 100 字符
- **AND** 验证 `DeviceType` 为预定义类型之一
- **AND** 验证 `Timestamp` 在合理时间范围内（±24小时）
- **AND** 验证失败时返回错误响应

### Requirement: 设备状态上报

桌面端必须通过 ILocalEventBus 订阅设备状态变化事件，并将事件转换为 SignalR 消息发送至服务端。

#### Scenario: 订阅设备状态事件

- **WHEN** MaterialClient 应用初始化
- **THEN** `DeviceStatusEventHandler` SHALL 注册为 ITransientDependency
- **AND** 实现 `ILocalEventHandler<StatusChangedEventData>` 接口
- **AND** 自动订阅所有设备状态变化事件

#### Scenario: 处理设备状态事件

- **假设** 设备状态事件包含设备类型和在线状态
- **WHEN** `DeviceStatusEventHandler` 接收到 `StatusChangedEventData` 事件
- **THEN** 处理器 SHALL 构造 `DeviceStatusMessage` 实例
- **AND** 设置 `ClientId` 为本地机器码或配置值
- **AND** 设置 `DeviceType` 为事件中的设备类型
- **AND** 设置 `Status` 为 "Online" 或 "Offline"
- **AND** 设置 `Timestamp` 为当前时间
- **AND** 调用 `DeviceStatusSignalRClient.UploadStatusAsync()`

#### Scenario: 发送状态消息至服务端

- **假设** SignalR 连接状态为 Connected
- **WHEN** `DeviceStatusSignalRClient.UploadStatusAsync()` 被调用
- **THEN** 客户端 SHALL 调用 HubConnection.SendAsync()
- **AND** 方法名为 "UploadStatus"
- **AND** 参数为序列化后的 `DeviceStatusMessage`
- **AND** 发送成功后返回

#### Scenario: 连接断开时缓存消息

- **假设** SignalR 连接状态为 Disconnected 或 Reconnecting
- **WHEN** `DeviceStatusSignalRClient.UploadStatusAsync()` 被调用
- **THEN** 客户端 SHALL 将消息加入内存缓存队列
- **AND** 队列最大容量为 100 条消息
- **AND** 超过容量时移除最旧消息（FIFO）
- **AND** 记录警告日志

### Requirement: 自动重连机制

客户端必须实现指数退避重连策略，在网络中断或服务重启场景下自动恢复连接。

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
- **AND** 记录信息日志

#### Scenario: 重连失败达到上限

- **假设** 连续重连失败 10 次
- **WHEN** 重连任务执行第 11 次尝试
- **THEN** 客户端 SHALL 停止自动重连
- **AND** 更新连接状态为 Disconnected
- **AND** 记录错误日志
- **AND** 触发 `ConnectionFailed` 事件

#### Scenario: 应用关闭时停止重连

- **WHEN** 应用正在关闭（`CancellationToken` 被取消）
- **THEN** 重连任务 SHALL 检测到取消信号
- **AND** 立即退出重连循环
- **AND** 不再尝试新的连接

### Requirement: 服务端状态处理

服务端必须提供 DeviceStatusService 处理接收到的设备状态消息，支持日志记录、消息分发和可选的持久化。

#### Scenario: 接收并验证消息

- **WHEN** DeviceStatusHub.UploadStatus() 方法被调用
- **THEN** 服务端 SHALL 验证消息格式合法性
- **AND** 验证 JWT Token 中的 ClientId 与消息中的 ClientId 一致
- **AND** 验证失败时返回错误响应
- **AND** 验证成功时调用 DeviceStatusService

#### Scenario: 处理状态变更

- **假设** 消息验证通过
- **WHEN** DeviceStatusService.HandleStatusUploadAsync() 被调用
- **THEN** 服务端 SHALL 记录信息日志（包含 ClientId、DeviceType、Status）
- **AND** 可选地将状态写入 DeviceStatusLog 表（如实体已定义）
- **AND** 调用 BroadcastToSubscribersAsync() 分发消息
- **AND** 返回成功响应

#### Scenario: 广播至订阅方

- **假设** 其他客户端订阅了特定设备类型的状态更新
- **WHEN** DeviceStatusService.BroadcastToSubscribersAsync() 被调用
- **THEN** 服务端 SHALL 查找订阅该设备类型的连接
- **AND** 使用 Clients.Clients() 发送消息至订阅方
- **AND** 消息格式为 "DeviceStatusUpdate" 事件
- **AND** 消息内容为原始 DeviceStatusMessage

#### Scenario: 记录处理失败

- **假设** 消息验证失败或处理过程中发生异常
- **WHEN** DeviceStatusService.HandleStatusUploadAsync() 捕获异常
- **THEN** 服务端 SHALL 记录错误日志（包含异常详情）
- **AND** 返回错误响应至客户端
- **AND** 不影响 Hub 继续处理后续消息

### Requirement: 连接生命周期管理

服务端必须管理客户端连接生命周期，跟踪连接/断开事件，支持连接元数据查询。

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
- **AND** 广播 "ClientDisconnected" 消息至其他订阅方

#### Scenario: 查询在线客户端

- **WHEN** 管理员查询当前在线客户端列表
- **THEN** 系统 SHALL 返回内存字典中的连接信息
- **AND** 包含 ClientId、ConnectionId、连接时间
- **AND** 不包含敏感信息如 JWT Token

### Requirement: 错误处理与日志

系统必须实现分层错误处理和完善的日志记录，支持问题诊断和运维监控。

#### Scenario: 客户端连接超时

- **假设** 服务端无响应或网络不可达
- **WHEN** HubConnection 尝试建立连接
- **THEN** 客户端 SHALL 捕获 TimeoutException
- **AND** 记录错误日志（包含目标 URL 和超时时长）
- **AND** 触发重连机制

#### Scenario: 消息发送失败

- **假设** SignalR 连接正常但 SendAsync() 调用失败
- **WHEN** UploadStatusAsync() 捕获异常
- **THEN** 客户端 SHALL 记录警告日志
- **AND** 将消息加入缓存队列
- **AND** 不抛出异常至调用方

#### Scenario: JWT Token 过期

- **假设** JWT Token 已过期但连接仍保持
- **WHEN** 客户端尝试调用 Hub 方法
- **THEN** 服务端 SHALL 返回 401 Unauthorized 错误
- **AND** 客户端检测到认证失败
- **AND** 触发 Token 刷新逻辑
- **AND** 重新建立连接

#### Scenario: 日志敏感信息脱敏

- **假设** 消息内容包含敏感信息（如设备 IP、序列号）
- **WHEN** 记录日志时
- **THEN** 系统 SHALL 对敏感字段进行脱敏处理
- **AND** IP 地址显示为 "192.168.*.*"
- **AND** 序列号显示为 "SN****"
- **AND** 日志级别根据严重程度正确设置

### Requirement: 性能与限流

系统必须实现消息限流和资源保护，防止高频状态变化导致系统过载。

#### Scenario: 消息发送限流

- **假设** 同一设备状态在 1 秒内变化 10 次
- **WHEN** DeviceStatusEventHandler 接收到事件
- **THEN** 处理器 SHALL 检查消息发送频率
- **AND** 限制同一设备每秒最多发送 1 条消息
- **AND** 超过限制时合并状态更新（仅保留最新状态）
- **AND** 记录调试日志

#### Scenario: 服务端消息处理限流

- **假设** 单个客户端每秒发送 100 条消息
- **WHEN** DeviceStatusHub 接收消息
- **THEN** 服务端 SHALL 检查客户端发送频率
- **AND** 限制单个客户端每秒最多处理 50 条消息
- **AND** 超过限制时返回 429 Too Many Requests
- **AND** 记录警告日志

#### Scenario: 内存使用监控

- **WHEN** DeviceStatusSignalRClient 运行时
- **THEN** 客户端 SHALL 监控缓存队列大小
- **AND** 队列大小超过 80 时记录警告
- **AND** 队列大小达到 100 时强制清理最旧消息
- **AND** 记录清理操作日志

### Requirement: 可配置性

系统必须支持通过配置文件调整关键参数，无需重新编译即可适配不同环境。

#### Scenario: 配置服务端 URL

- **WHEN** MaterialClient 应用启动
- **THEN** 系统 SHALL 从 `appsettings.json` 读取 `SignalR:ServerUrl` 配置
- **AND** 默认值为 `"http://localhost:5000/hubs/devicestatus"`
- **AND** 支持完整 URL 格式（包含协议和路径）

#### Scenario: 配置重连参数

- **WHEN** DeviceStatusSignalRClient 初始化
- **THEN** 系统 SHALL 从配置读取重连参数
- **AND** `SignalR:ReconnectDelays` 为数组格式 `[0, 2, 10, 30]`
- **AND** `SignalR:MaxReconnectAttempts` 默认为 10
- **AND** 配置无效时使用默认值

#### Scenario: 配置消息队列大小

- **WHEN** DeviceStatusSignalRClient 初始化
- **THEN** 系统 SHALL 从配置读取队列大小限制
- **AND** `SignalR:MessageQueueSize` 默认为 100
- **AND** 配置值必须大于 0 且不超过 1000
- **AND** 超出范围时使用默认值

#### Scenario: 配置服务端 CORS

- **WHEN** UrbanManagement 应用启动
- **THEN** 系统 SHALL 从配置读取允许的来源
- **AND** `SignalR:AllowedOrigins` 为数组格式
- **AND** 默认包含 `http://localhost:*` 和 `http://127.0.0.1:*`
- **AND** 空数组时拒绝所有跨域请求
