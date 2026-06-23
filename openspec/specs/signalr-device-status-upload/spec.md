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
- **AND** 包含 `ProId` 字段（string，项目主键，用于聚合和缓存，从 LicenseInfo.ProjectId 读取）
- **AND** 包含 `ProName` 字段（string，项目展示名称，从 LicenseInfo.ProName 读取）
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

桌面端必须通过 ILocalEventBus 订阅设备状态变化事件，并将事件转换为包含 ProId 和 ProName 的 SignalR 消息发送至服务端。

#### Scenario: 订阅设备状态事件

- **WHEN** MaterialClient 应用初始化
- **THEN** `DeviceStatusEventHandler` SHALL 注册为 ITransientDependency
- **AND** 实现 `ILocalEventHandler<StatusChangedEventData>` 接口
- **AND** 自动订阅所有设备状态变化事件

#### Scenario: 处理设备状态事件

- **假设** 设备状态事件包含设备类型和在线状态
- **WHEN** `DeviceStatusEventHandler` 接收到 `StatusChangedEventData` 事件
- **THEN** 处理器 SHALL 从 `ILicenseService.GetCurrentLicenseAsync()` 读取 LicenseInfo
- **AND** 设置 `ProId` 为 `LicenseInfo.ProjectId.ToString()`（主键）
- **AND** 设置 `ProName` 为 `LicenseInfo.ProName`（展示名称）
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
- **AND** 当 ProId 非空时 SHALL 使用 ProId 作为聚合和缓存主键
- **AND** 当 ProId 为空时 SHALL 降级使用 ClientId 作为标识
- **AND** 验证失败时返回错误响应
- **AND** 验证成功时调用 DeviceStatusService

#### Scenario: 处理状态变更

- **假设** 消息验证通过
- **WHEN** DeviceStatusService.HandleStatusUploadAsync() 被调用
- **THEN** 服务端 SHALL 记录信息日志（包含 ProId、ClientId、DeviceType、Status）
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

### Requirement: 客户端日志拉取能力注册

DeviceStatusHub 必须提供客户端注册日志拉取能力的方法。

#### Scenario: 注册日志拉取能力

- **假设** 客户端支持日志拉取功能
- **WHEN** 客户端调用 `RegisterLogCapability(clientId, capability)`
- **THEN** 系统 SHALL 验证 `clientId` 为非空字符串
- **AND** 验证 `capability.SupportsLogPull` 为 `true`
- **AND** 将客户端能力信息记录到内存字典（`Dictionary<string, LogCapabilityInfo>`）
- **AND** 调用 `Clients.Caller.SendAsync("LogCapabilityRegistered", clientId)`
- **AND** 记录信息日志（包含 `clientId` 和 `capability.LogDirectory`）

#### Scenario: 重复注册处理

- **假设** 同一 `clientId` 已注册能力
- **WHEN** 客户端再次调用 `RegisterLogCapability`
- **THEN** 系统 SHALL 更新内存字典中的能力信息
- **AND** 记录调试日志（"客户端 {clientId} 更新日志拉取能力"）
- **AND** 不抛出异常

#### Scenario: 能力信息验证

- **WHEN** 接收 `LogCapabilityInfo` 参数
- **THEN** 系统 SHALL 验证 `SupportsLogPull` 为布尔值
- **AND** 验证 `LogDirectory` 为有效路径格式
- **AND** 验证 `MaxConcurrentDownloads` 为正整数（1-10）
- **AND** 验证失败时 SHALL 记录警告日志并忽略无效字段

### Requirement: 请求客户端日志列表

DeviceStatusHub 必须提供服务端请求客户端日志列表的方法。

#### Scenario: 发送日志列表请求

- **假设** 服务端用户选择客户端和日期
- **WHEN** 服务端调用 `RequestLogList(requestId, clientId, dateFolder)`
- **THEN** 系统 SHALL 生成唯一 `requestId`（GUID 字符串）
- **AND** 验证 `clientId` 在内存字典中存在
- **AND** 验证客户端已注册 `SupportsLogPull = true`
- **AND** 查找 `clientId` 对应的 SignalR 连接 ID
- **AND** 调用 `Clients.Client(connectionId).SendAsync("ReceiveLogListRequest", requestId, clientId, dateFolder)`
- **AND** 记录调试日志（包含 `requestId` 和 `dateFolder`）

#### Scenario: 客户端离线处理

- **假设** `clientId` 对应的客户端未连接
- **WHEN** 服务端调用 `RequestLogList`
- **THEN** 系统 SHALL 检测连接不存在
- **AND** 记录警告日志（"客户端 {clientId} 未连接，无法请求日志列表"）
- **AND** 不抛出异常（方法正常返回）
- **AND** 调用方负责超时处理

#### Scenario: 参数验证

- **WHEN** 接收 `RequestLogList` 参数
- **THEN** 系统 SHALL 验证 `requestId` 为非空 GUID
- **AND** 验证 `clientId` 为非空字符串（1-100 字符）
- **AND** 验证 `dateFolder` 格式为 `YYYY/MM/DD/` 或 `YYYY-MM-DD`
- **AND** 验证失败时 SHALL 记录警告日志并返回

### Requirement: 返回客户端日志列表

DeviceStatusHub 必须提供客户端返回日志列表响应的方法。

#### Scenario: 接收日志列表响应

- **假设** 客户端完成文件扫描
- **WHEN** 客户端调用 `ReturnLogList(requestId, result)`
- **THEN** 系统 SHALL 验证 `requestId` 为有效 GUID
- **AND** 验证 `result` 为非空对象
- **AND** 验证 `result.Files` 为非空数组
- **AND** 查找订阅该 `requestId` 的 HTTP 会话（通过 SignalR Group "LogRequesters"）
- **AND** 调用 `Clients.Group("LogRequesters").SendAsync("LogListReceived", new {requestId, result})`
- **AND** 记录调试日志（包含文件数量和总大小）

#### Scenario: 响应数据格式

- **WHEN** 接收 `ClientLogListResultDto` 对象
- **THEN** 系统 SHALL 验证对象结构包含：
  - `RequestId`（string，GUID）
  - `ClientId`（string）
  - `DateFolder`（string）
  - `Files`（数组，包含 `LogFileDto`）
  - `TotalSize`（long，字节）
  - `ScannedAt`（DateTime）
- **AND** 验证失败时 SHALL 记录错误日志并忽略响应

#### Scenario: 未订阅的 RequestId

- **假设** `requestId` 没有对应的订阅者
- **WHEN** 客户端调用 `ReturnLogList`
- **THEN** 系统 SHALL 检测 Group "LogRequesters" 为空
- **AND** 记录警告日志（"RequestId {requestId} 无订阅者，响应将被丢弃"）
- **AND** 不抛出异常
- **AND** 方法正常返回

### Requirement: 日志请求者订阅管理

DeviceStatusHub 必须提供 HTTP 会话订阅日志响应的方法。

#### Scenario: 订阅日志响应

- **假设** HTTP 会话需要接收日志列表响应
- **WHEN** HTTP 会话调用 `SubscribeLogRequests(requestId)`
- **THEN** 系统 SHALL 验证 `requestId` 为有效 GUID
- **AND** 调用 `Groups.AddToGroupAsync(Context.ConnectionId, "LogRequesters")`
- **AND** 在 `Context.Items` 中记录 `requestId`
- **AND** 记录调试日志（"Connection {ConnectionId} 订阅日志响应 {requestId}"）

#### Scenario: 取消订阅

- **假设** HTTP 会话完成日志拉取或超时
- **WHEN** HTTP 会话调用 `UnsubscribeLogRequests(requestId)`
- **THEN** 系统 SHALL 验证 `requestId` 与 `Context.Items` 中记录匹配
- **AND** 调用 `Groups.RemoveFromGroupAsync(Context.ConnectionId, "LogRequesters")`
- **AND** 清除 `Context.Items` 中的 `requestId`
- **AND** 记录调试日志

#### Scenario: 会话断开时清理订阅

- **假设** HTTP 会话意外断开
- **WHEN** `OnDisconnectedAsync` 触发
- **THEN** 系统 SHALL 检查 `Context.Items` 中的 `requestId`
- **AND** 如存在 SHALL 自动从 "LogRequesters" Group 移除
- **AND** 清理内存字典中的订阅记录
- **AND** 记录信息日志

### Requirement: 内存字典管理

DeviceStatusHub 必须安全地管理客户端能力和订阅信息的内存字典。

#### Scenario: 线程安全访问

- **假设** 多个线程同时访问内存字典
- **WHEN** 读写 `ConcurrentDictionary<string, LogCapabilityInfo>`
- **THEN** 系统 SHALL 使用内置线程安全方法
- **AND** `TryAdd`、`TryUpdate`、`TryRemove` 操作 SHALL 原子执行
- **AND** 不需要额外锁

#### Scenario: 内存字典清理

- **假设** 客户端断开连接
- **WHEN** `OnDisconnectedAsync` 触发
- **THEN** 系统 SHALL 从内存字典中移除客户端能力信息
- **AND** 清理相关的订阅信息
- **AND** 记录信息日志（"客户端 {clientId} 能力信息已清理"）

#### Scenario: 内存字典容量限制

- **假设** 内存字典条目超过 1000
- **WHEN** 尝试添加新条目
- **THEN** 系统 SHALL 记录警告日志（"内存字典接近容量限制"）
- **AND** 继续添加新条目（不拒绝）
- **AND** 建议运维人员检查异常连接

### Requirement: 与现有功能隔离

新增的日志拉取功能不得影响现有的设备状态上传功能。

#### Scenario: 设备状态上传不受影响

- **假设** 日志拉取方法正在执行
- **WHEN** 客户端调用 `UploadStatus` 方法
- **THEN** 系统 SHALL 正常处理设备状态消息
- **AND** 日志拉取操作 SHALL 不阻塞 `UploadStatus` 执行
- **AND** 两个功能 SHALL 独立运行

#### Scenario: 性能隔离

- **假设** 客户端同时发送设备状态和日志请求
- **WHEN** Hub 处理并发请求
- **THEN** 系统 SHALL 使用独立的处理线程
- **AND** 日志拉取的超时配置 SHALL 不影响设备状态上传
- **AND** 一个功能的错误 SHALL 不影响另一个功能

#### Scenario: 连接生命周期共享

- **WHEN** 客户端连接或断开
- **THEN** `OnConnectedAsync` 和 `OnDisconnectedAsync` SHALL 正常执行
- **AND** 现有的连接/断开日志 SHALL 正常记录
- **AND** 新增的日志能力清理 SHALL 不抛出异常
