# Client Log SignalR Pull Service Specification

## Purpose

定义 MaterialClient.Urban 客户端的 SignalR 日志拉取服务要求，包括能力注册、日志列表请求处理、错误处理和与 DeviceStatusHub 的集成。

## Requirements

### Requirement: SignalR 连接初始化

客户端必须初始化与服务端的 SignalR 连接，并注册日志拉取能力。

#### Scenario: 启动日志拉取服务

- **假设** `appsettings.json` 配置了有效的 `UrbanManagement:BaseUrl`
- **WHEN** MaterialClient.Urban 应用初始化
- **THEN** `ClientLogPullService` SHALL 创建 HubConnection 实例
- **AND** 连接端点为 `{BaseUrl}/hubs/devicestatus`
- **AND** 配置 JWT AccessTokenProvider
- **AND** 注册 `ReceiveLogListRequest` 回调
- **AND** 调用 `StartAsync()` 建立连接

#### Scenario: 注册日志拉取能力

- **假设** SignalR 连接状态为 Connected
- **WHEN** 连接成功建立
- **THEN** 系统 SHALL 调用 `RegisterLogCapability` Hub 方法
- **AND** 参数包含 `ClientId`（从 `Client:Id` 读取或机器名）
- **AND** 参数包含 `LogCapabilityInfo` 对象
- **AND** `LogCapabilityInfo.SupportsLogPull` 为 `true`
- **AND** `LogCapabilityInfo.LogDirectory` 为 `Logs/` 目录绝对路径
- **AND** `LogCapabilityInfo.MaxConcurrentDownloads` 为 `3`
- **AND** 注册成功后记录信息日志

#### Scenario: 配置无效时跳过

- **假设** `UrbanManagement:BaseUrl` 为空或无效
- **WHEN** `ClientLogPullService.InitializeAsync()` 被调用
- **THEN** 系统 SHALL 记录警告日志
- **AND** 不抛出异常
- **AND** 日志拉取功能不可用
- **AND** 主程序继续运行

#### Scenario: ClientId 来源

- **WHEN** 构建客户端标识
- **THEN** 系统 SHALL 优先从 `Client:Id` 配置读取
- **AND** 配置为空时 SHALL 使用 `Environment.MachineName`
- **AND** ClientId SHALL 不超过 100 字符
- **AND** 过长时 SHALL 截断并记录警告

### Requirement: 接收日志列表请求

客户端必须响应服务端的日志列表请求，扫描指定日期目录并返回文件列表。

#### Scenario: 处理日志列表请求

- **假设** 客户端已注册 `ReceiveLogListRequest` 回调
- **WHEN** 服务端调用 `Clients.Client(clientId).SendAsync("ReceiveLogListRequest", requestId, clientId, dateFolder)`
- **THEN** 系统 SHALL 调用 `HandleLogListRequestAsync(requestId, clientId, dateFolder)`
- **AND** 验证 `clientId` 与当前客户端标识匹配
- **AND** 不匹配时 SHALL 忽略请求并记录警告

#### Scenario: 扫描日志目录

- **假设** 请求的 `dateFolder` 为 `2025/06/22/`
- **WHEN** `HandleLogListRequestAsync` 执行
- **THEN** 系统 SHALL 构建目标路径 `Logs/2025/06/22/`
- **AND** 验证路径在 `Logs/` 目录内（防止目录遍历）
- **AND** 目录存在时 SHALL 扫描所有 `.log` 文件
- **AND** 目录不存在时 SHALL 返回空文件列表

#### Scenario: 构建文件列表响应

- **假设** 目标目录包含 3 个日志文件
- **WHEN** 文件扫描完成
- **THEN** 系统 SHALL 创建 `ClientLogListResultDto` 对象
- **AND** 包含 `RequestId`（从请求复制）
- **AND** 包含 `ClientId`（当前客户端标识）
- **AND** 包含 `DateFolder`（请求的日期目录）
- **AND** 包含 `Files` 数组，每个元素包含：
  - `FileName`：文件名（如 `MaterialClient-20250622.log`）
  - `FilePath`：相对路径（如 `2025/06/22/`）
  - `FileSize`：文件大小（字节）
  - `LastModified`：最后修改时间（DateTime）
- **AND** 包含 `TotalSize`：所有文件大小总和
- **AND** 包含 `ScannedAt`：扫描时间戳

#### Scenario: 返回文件列表

- **WHEN** `ClientLogListResultDto` 构建完成
- **THEN** 系统 SHALL 调用 `ReturnLogList` Hub 方法
- **AND** 参数为 `requestId` 和 `result` 对象
- **AND** 发送成功后记录调试日志
- **AND** 发送失败时 SHALL 记录错误日志但不影响主程序

#### Scenario: 处理扫描异常

- **假设** 目录扫描过程中发生异常（如权限不足）
- **WHEN** `HandleLogListRequestAsync` 捕获异常
- **THEN** 系统 SHALL 记录错误日志
- **AND** 不调用 `ReturnLogList`（避免发送无效数据）
- **AND** 不抛出异常至 SignalR 管道

### Requirement: 回调注册和管理

客户端必须正确注册和注销 SignalR 回调。

#### Scenario: 注册回调

- **WHEN** HubConnection 创建
- **THEN** 系统 SHALL 调用 `_hubConnection.On<string, string, string>("ReceiveLogListRequest", ...)`
- **AND** 回调 SHALL 在后台线程执行
- **AND** 回调 SHALL 调用 `HandleLogListRequestAsync`
- **AND** 注册 SHALL 在 `StartAsync()` 之前完成

#### Scenario: 回调线程安全

- **假设** 多个日志列表请求同时到达
- **WHEN** 回调并发执行
- **THEN** 系统 SHALL 使用 `async/await` 模式
- **AND** 文件 I/O 操作 SHALL 异步执行
- **AND** 不阻塞 SignalR 线程
- **AND** 支持至少 3 个并发请求

### Requirement: 服务生命周期管理

客户端必须在应用关闭时优雅停止日志拉取服务。

#### Scenario: 优雅停止

- **WHEN** MaterialClient.Urban 应用关闭
- **THEN** 系统 SHALL 调用 `DisposeAsync()`
- **AND** 如果 HubConnection 状态为 Connected
- **AND** SHALL 调用 `StopAsync()`
- **AND** SHALL 等待断开完成（超时 5 秒）
- **AND** 释放所有资源
- **AND** 超时后 SHALL 强制关闭

#### Scenario: 重连不影响能力

- **假设** SignalR 连接断开后重连成功
- **WHEN** 重连完成
- **THEN** 系统 SHALL 自动重新注册 `LogCapability`
- **AND** 使用相同的 `ClientId` 和 `LogCapabilityInfo`
- **AND** 记录重连注册日志

### Requirement: 日志记录和诊断

日志拉取服务必须记录关键操作和错误信息。

#### Scenario: 记录服务启动

- **WHEN** `ClientLogPullService.InitializeAsync()` 开始执行
- **THEN** 系统 SHALL 记录信息日志
- **AND** 日志包含服务端 URL
- **AND** 日志包含 ClientId
- **AND** 配置无效时 SHALL 记录警告

#### Scenario: 记录请求处理

- **WHEN** `ReceiveLogListRequest` 回调触发
- **THEN** 系统 SHALL 记录调试日志
- **AND** 日志包含 `RequestId` 和 `DateFolder`
- **AND** 日志包含扫描到的文件数量
- **AND** 处理时间超过 1 秒时 SHALL 记录性能警告

#### Scenario: 记录错误

- **假设** 任何步骤失败（连接、注册、扫描、发送）
- **WHEN** 捕获异常
- **THEN** 系统 SHALL 记录错误日志
- **AND** 日志包含异常类型和消息
- **AND** 日志包含 `RequestId`（如适用）
- **AND** 不影响主程序运行

### Requirement: 配置管理

日志拉取服务行为必须可通过配置调整。

#### Scenario: 读取服务端 URL

- **WHEN** 读取 `appsettings.json`
- **THEN** 系统 SHALL 从 `UrbanManagement:BaseUrl` 读取
- **AND** 默认值为 `http://localhost:5000`
- **AND** URL SHALL 包含协议（http 或 https）
- **AND** URL SHALL 不包含尾部斜杠

#### Scenario: 读取客户端标识

- **WHEN** 读取 `appsettings.json`
- **THEN** 系统 SHALL 从 `Client:Id` 读取
- **AND** 默认值为 `Environment.MachineName`
- **AND** 值 SHALL 在 1-100 字符范围内

#### Scenario: 读取日志目录

- **WHEN** 读取 `appsettings.json`
- **THEN** 系统 SHALL 从 `Log:Directory` 读取
- **AND** 默认值为 `Logs`
- **AND** 目录 SHALL 相对于应用基目录
- **AND** 支持绝对路径

### Requirement: 错误恢复

日志拉取服务必须从临时错误中自动恢复。

#### Scenario: 网络中断恢复

- **假设** 服务端网络临时中断
- **WHEN** HubConnection 检测到断开
- **THEN** 系统 SHALL 触发重连机制
- **AND** 重连成功后 SHALL 重新注册 `LogCapability`
- **AND** 不记录错误日志（仅调试）

#### Scenario: 注册失败重试

- **假设** `RegisterLogCapability` 调用失败（服务端繁忙）
- **WHEN** 捕获 `HubException`
- **THEN** 系统 SHALL 记录警告日志
- **AND** 等待 5 秒后重试
- **AND** 最多重试 3 次
- **AND** 超过重试次数后 SHALL 停止尝试
- **AND** 日志拉取功能降级为不可用

#### Scenario: 文件系统错误

- **假设** 日志目录被外部程序锁定
- **WHEN** 扫描文件时抛出 `IOException`
- **THEN** 系统 SHALL 返回空文件列表
- **AND** 记录警告日志（包含目录路径）
- **AND** 不影响 SignalR 连接
