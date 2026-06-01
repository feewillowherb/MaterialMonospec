# SignalR Device Status Upload - Implementation Tasks

## 1. 服务端基础设施

### 1.1 依赖配置

- [x] 1.1.1 验证 UrbanManagement 项目中 ABP Framework 已包含 SignalR 支持
- [x] 1.1.2 在 `UrbanManagement.App/appsettings.json` 中添加 SignalR 配置节点
- [x] 1.1.3 在 `UrbanManagementAppModule.cs` 中添加 SignalR 服务注册和 CORS 配置

### 1.2 核心 Hub 实现

- [x] 1.2.1 创建 `UrbanManagement.Core/Hubs/` 目录
- [x] 1.2.2 实现 `DeviceStatusHub` 类，继承 `Hub`
- [x] 1.2.3 实现 `OnConnectedAsync()` 方法，记录连接日志
- [x] 1.2.4 实现 `OnDisconnectedAsync()` 方法，清理连接信息
- [x] 1.2.5 实现 `UploadStatus(DeviceStatusMessage)` 方法，接收设备状态消息
- [x] 1.2.6 实现 `SubscribeDeviceUpdates(string)` 方法，支持订阅管理
- [x] 1.2.7 实现 `SayHello(string message)` 测试方法，日志打印接收到的消息

## 2. 服务端应用服务层

### 2.1 DTO 和模型定义

- [x] 2.1.1 创建 `UrbanManagement.Core/Models/DeviceStatusMessage.cs` record 类型
- [x] 2.1.2 添加所有必需字段：ClientId、DeviceType、Status、Timestamp、AdditionalData
- [x] 2.1.3 实现 Json 序列化特性（CamelCase 命名策略）

### 2.2 DeviceStatusService 实现

- [x] 2.2.1 创建 `UrbanManagement.Core/Services/IDeviceStatusService.cs` 接口
- [x] 2.2.2 定义 `HandleStatusUploadAsync(DeviceStatusMessage)` 方法签名
- [x] 2.2.3 定义 `BroadcastToSubscribersAsync(string deviceType, object message)` 方法签名
- [x] 2.2.4 实现 `DeviceStatusService` 类，标记 `ITransientDependency`
- [x] 2.2.5 实现消息验证逻辑（ClientId 一致性、时间范围检查）
- [x] 2.2.6 实现日志记录逻辑（信息日志、错误日志）
- [x] 2.2.7 实现消息分发逻辑（调用 Hub.Clients.Clients()）
- [x] 2.2.8 为所有数据写入方法添加 `[UnitOfWork]` 特性
- [x] 2.2.9 在 `DeviceStatusService` 中注入 `IDistributedCache` 依赖
- [x] 2.2.10 实现 ABP 内存缓存逻辑（最多 100 条消息，FIFO）
- [x] 2.2.11 实现缓存消息读取和清空逻辑（重连后补发）

### 2.3 可选持久化支持

- [x] 2.3.1 创建 `UrbanManagement.Core/Entities/DeviceStatusLog.cs` 实体（如需持久化）
- [ ] 2.3.2 在 `DbContext` 中添加 `DbSet<DeviceStatusLog>`（如需持久化）
- [ ] 2.3.3 在 `DeviceStatusService` 中添加持久化逻辑（如实体已定义）

### 2.4 配置选项

- [x] 2.4.1 创建 `UrbanManagement.Core/Configuration/SignalROptions.cs` 配置类
- [x] 2.4.2 添加 `AllowedOrigins` 字符串数组属性
- [x] 2.4.3 添加 `MessageSizeLimit` 整型属性
- [x] 2.4.4 在 `appsettings.json` 中添加配置映射

## 3. 桌面端基础设施

### 3.1 依赖包添加

- [x] 3.1.1 在 MaterialClient `Directory.Packages.props` 中添加 `Microsoft.AspNetCore.SignalR.Client` 包
- [ ] 3.1.2 执行 `dotnet restore` 恢复依赖

### 3.2 配置设置

- [x] 3.2.1 创建 `MaterialClient.Common/Configuration/SignalRClientOptions.cs` 配置类
- [x] 3.2.2 添加 `ServerUrl` 字符串属性
- [x] 3.2.3 添加 `ReconnectDelays` 整型数组属性
- [x] 3.2.4 添加 `MaxReconnectAttempts` 整型属性
- [x] 3.2.5 添加 `MessageQueueSize` 整型属性
- [x] 3.2.6 在 `MaterialClient.Urban/appsettings.json` 中添加 SignalR 配置节点

## 4. 桌面端 SignalR 客户端

### 4.1 核心 SignalR 客户端实现

- [x] 4.1.1 创建 `MaterialClient.Common/Services/DeviceStatusSignalRClient.cs` 类
- [x] 4.1.2 标记为 `ISingletonDependency` 单例服务
- [x] 4.1.3 实现 `IAsyncDisposable` 接口支持资源释放
- [x] 4.1.4 添加 `HubConnection` 私有字段和连接状态变化事件
- [x] 4.1.5 实现 `StartAsync()` 方法，创建和配置 HubConnection
- [x] 4.1.6 在 `StartAsync()` 中配置 JWT AccessTokenProvider
- [x] 4.1.7 实现 `StopAsync()` 方法，停止重连并释放连接
- [x] 4.1.8 实现 `UploadStatusAsync(DeviceStatusMessage)` 方法
- [x] 4.1.9 实现连接状态判断逻辑（Connected 时发送，Disconnected 时写入缓存）
- [x] 4.1.10 确认服务端已配置 ABP 内存缓存（IDistributedCache），客户端仅负责消息发送

### 4.2 自动重连机制

- [x] 4.2.1 实现 `ReconnectLoopAsync()` 私有方法
- [x] 4.2.2 实现指数退避延迟逻辑（0s、2s、10s、30s，最大 60s）
- [x] 4.2.3 实现重连次数限制（最多 10 次）
- [x] 4.2.4 实现连接恢复后消息补发逻辑
- [x] 4.2.5 订阅 HubConnection 的 `Closed` 事件触发重连
- [x] 4.2.6 订阅 HubConnection 的 `Reconnecting` 和 `Reconnected` 事件
- [x] 4.2.7 实现应用关闭时的 `CancellationToken` 取消检测

### 4.3 错误处理

- [x] 4.3.1 实现连接超时异常处理和日志记录
- [x] 4.3.2 实现消息发送失败时的临时存储逻辑（依赖服务端 ABP 缓存）
- [x] 4.3.3 实现 JWT Token 过期时的刷新和重连逻辑
- [x] 4.3.4 实现配置验证失败时的异常抛出

## 5. 桌面端事件集成

### 5.1 DTO 共享模型

- [x] 5.1.1 创建 `MaterialClient.Common/Models/DeviceStatusMessage.cs` record 类型
- [x] 5.1.2 确保与服务端字段结构一致（ClientId、DeviceType、Status、Timestamp、AdditionalData）
- [x] 5.1.3 添加 Json 序列化特性确保兼容性

### 5.2 事件处理器实现

- [x] 5.2.1 创建 `MaterialClient.Common/Events/DeviceStatusEventHandler.cs` 类
- [x] 5.2.2 实现 `ILocalEventHandler<DeviceStatusChangedEventData>` 接口
- [x] 5.2.3 标记为 `ITransientDependency` 注册到 DI 容器
- [x] 5.2.4 注入 `DeviceStatusSignalRClient` 依赖
- [x] 5.2.5 实现 `HandleEventAsync(DeviceStatusChangedEventData)` 方法
- [x] 5.2.6 在 `HandleEventAsync` 中构建设备状态消息
- [x] 5.2.7 调用 `DeviceStatusSignalRClient.UploadStatusAsync()`

### 5.3 依赖注入注册

- [x] 5.3.1 在 `MaterialClientUrbanModule.cs` 中注册 `DeviceStatusSignalRClient`
- [x] 5.3.2 注册 `DeviceStatusEventHandler`（ITransientDependency 自动注册）
- [x] 5.3.3 确认 `ILocalEventBus` 已在模块中配置

## 6. 消息限流和性能优化

### 6.1 客户端限流

- [x] 6.1.1 在 `DeviceStatusEventHandler` 中实现消息发送频率检查
- [x] 6.1.2 限制同一设备每秒最多发送 1 条消息
- [x] 6.1.3 实现状态合并逻辑（保留最新状态）
- [x] 6.1.4 添加调试日志记录限流操作

### 6.2 服务端限流

- [x] 6.2.1 在 `DeviceStatusHub` 中实现客户端发送频率检查
- [x] 6.2.2 限制单个客户端每秒最多处理 50 条消息
- [x] 6.2.3 超过限制时返回 429 Too Many Requests 响应
- [x] 6.2.4 添加警告日志记录限流触发

## 7. 测试和验证

### 7.1 单元测试

- [ ] 7.1.1 创建 `DeviceStatusServiceTests` 测试类
- [ ] 7.1.2 实现消息验证逻辑的单元测试
- [ ] 7.1.3 实现 `DeviceStatusMessage` 序列化/反序列化测试
- [ ] 7.1.4 创建 `DeviceStatusSignalRClientTests` 测试类（Mock HubConnection）
- [ ] 7.1.5 实现连接管理逻辑的单元测试
- [ ] 7.1.6 实现重连机制的单元测试

### 7.2 集成测试

- [ ] 7.2.1 启动 UrbanManagement 服务端，验证 `/hubs/devicestatus` 端点可访问
- [ ] 7.2.2 使用 SignalR 客户端工具（如 Postman）测试连接和消息发送
- [ ] 7.2.3 验证 JWT 认证流程（正常 Token 和过期 Token）
- [ ] 7.2.4 验证 CORS 配置（跨域请求）
- [ ] 7.2.5 启动 MaterialClient 桌面端，检查日志确认连接成功

### 7.3 端到端测试

- [ ] 7.3.1 桌面端触发设备状态变化（如断开摄像头）
- [ ] 7.3.2 观察服务端日志，确认接收设备状态消息
- [ ] 7.3.3 验证消息格式正确（所有字段完整）
- [ ] 7.3.4 模拟网络中断，验证客户端自动重连
- [ ] 7.3.5 验证重连后缓存消息补发
- [ ] 7.3.6 测试 JWT Token 过期场景的刷新逻辑
- [ ] 7.3.7 客户端调用 `SayHello()` 方法，验证服务端推送和日志打印
- [ ] 7.3.8 测试 ABP 内存缓存功能（验证 100 条消息限制、FIFO 顺序）

### 7.4 性能测试

- [ ] 7.4.1 模拟高频状态变化（每秒 10 次），验证限流机制
- [ ] 7.4.2 测试内存队列最大容量（100 条消息）
- [ ] 7.4.3 监控应用内存使用，确认无内存泄漏
- [ ] 7.4.4 测试长时间运行稳定性（运行 24 小时）

## 8. 文档和部署

### 8.1 配置文档

- [ ] 8.1.1 更新 UrbanManagement 部署文档，说明 SignalR 配置要求
- [ ] 8.1.2 更新 MaterialClient 配置文档，说明 SignalR 客户端配置
- [ ] 8.1.3 创建故障排查指南（连接失败、重连问题）
- [ ] 8.1.4 记录日志查看方法和关键字

### 8.2 数据库迁移（可选）

- [ ] 8.2.1 如需持久化，创建 `DeviceStatusLog` 实体的 EF Migration
- [ ] 8.2.2 在开发环境执行 Migration 验证表结构
- [ ] 8.2.3 准备生产环境 Migration 脚本（由用户手动执行）

### 8.3 部署验证

- [ ] 8.3.1 在测试环境部署 UrbanManagement 新版本
- [ ] 8.3.2 在测试环境部署 MaterialClient 新版本
- [ ] 8.3.3 执行端到端测试验证功能正常
- [ ] 8.3.4 收集测试反馈并修复问题
- [ ] 8.3.5 准备生产环境部署计划

## 9. 清理和收尾

### 9.1 代码审查

- [x] 9.1.1 检查所有代码符合跨子仓库 C# 编码约定（无 tuple，使用 record）
- [x] 9.1.2 验证 Service 方法正确使用 `[UnitOfWork]` 特性
- [x] 9.1.3 确认 ViewModels 没有直接使用 Repository
- [x] 9.1.4 检查日志记录中敏感信息已脱敏
- [x] 9.1.5 验证异常处理完善，无未处理异常

### 9.2 文档更新

- [ ] 9.2.1 更新 UrbanManagement AGENTS.md（如有新增约定）
- [ ] 9.2.2 更新 MaterialClient AGENTS.md（如有新增约定）
- [ ] 9.2.3 确认主仓库 AGENTS.md 无需更新

### 9.3 变更归档准备

- [ ] 9.3.1 确认所有任务已完成
- [ ] 9.3.2 检查所有 artifact 文件完整
- [ ] 9.3.3 准备变更归档
