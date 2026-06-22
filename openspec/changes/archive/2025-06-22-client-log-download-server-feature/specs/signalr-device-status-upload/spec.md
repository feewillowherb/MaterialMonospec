# SignalR Device Status Upload Specification - Delta

## Purpose

本文档为 `signalr-device-status-upload` 规范的增量规范，记录新增的客户端日志拉取相关方法和扩展功能。本变更不影响现有的设备状态上传功能。

## MODIFIED Requirements

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

## ADDED Requirements

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
