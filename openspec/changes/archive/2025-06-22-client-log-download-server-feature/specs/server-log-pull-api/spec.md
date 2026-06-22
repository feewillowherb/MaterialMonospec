# Server Log Pull API Specification

## Purpose

定义 UrbanManagement 服务端的客户端日志拉取 API 要求，包括 SignalR Hub 扩展、应用服务、实体模型、权限控制和静态文件缓存。

## ADDED Requirements

### Requirement: DeviceStatusHub 日志方法扩展

服务端必须扩展现有 DeviceStatusHub，新增日志拉取相关方法。

#### Scenario: 注册日志拉取能力

- **假设** 客户端调用 `RegisterLogCapability(clientId, capability)`
- **WHEN** 方法执行
- **THEN** 系统 SHALL 验证 `clientId` 非空
- **AND** 验证 `capability.SupportsLogPull` 为 `true`
- **AND** 记录客户端日志拉取能力到内存字典
- **AND** 调用 `Clients.Caller.SendAsync("LogCapabilityRegistered", clientId)`
- **AND** 记录信息日志

#### Scenario: 请求日志列表

- **假设** 服务端调用 `RequestLogList(requestId, clientId, dateFolder)`
- **WHEN** 方法执行
- **THEN** 系统 SHALL 查找 `clientId` 对应的 SignalR 连接
- **AND** 连接存在时 SHALL 调用 `Clients.Client(connectionId).SendAsync("ReceiveLogListRequest", requestId, clientId, dateFolder)`
- **AND** 连接不存在时 SHALL 记录警告日志并返回
- **AND** 参数 `dateFolder` 格式 SHALL 为 `YYYY/MM/DD/` 或 `YYYY-MM-DD`

#### Scenario: 返回日志列表

- **假设** 客户端调用 `ReturnLogList(requestId, result)`
- **WHEN** 方法执行
- **THEN** 系统 SHALL 验证 `requestId` 非空
- **AND** 验证 `result.Files` 不为 null
- **AND** 查找订阅 `RequestId` 的连接（如 `requestId` 对应的 HTTP 会话）
- **AND** 调用 `Clients.Group("LogRequesters").SendAsync("LogListReceived", {requestId, result})`
- **AND** 记录调试日志

### Requirement: ClientLogAppService 服务

服务端必须提供客户端日志应用服务，处理日志列表查询、拉取和缓存管理。

#### Scenario: 获取在线客户端列表

- **WHEN** 调用 `GetOnlineClientsAsync()`
- **THEN** 系统 SHALL 查询 `ClientInfo` 表（`IsOnline = true`）
- **AND** 返回 `List<ClientInfoDto>`
- **AND** 包含 `ClientId`、`ClientName`、`LastConnectedAt`、`SupportsLogPull` 字段
- **AND** 按 `LastConnectedAt` 降序排列

#### Scenario: 请求客户端日志列表

- **假设** `input.ClientId` 为 "material-client-001"，`input.Date` 为 "2025-06-22"
- **WHEN** 调用 `RequestLogListAsync(input)`
- **THEN** 系统 SHALL 生成唯一 `requestId`（GUID）
- **AND** 调用 `DeviceStatusHub` 的 `RequestLogList` 方法
- **AND** 等待客户端响应（超时 30 秒）
- **AND** 返回 `ClientLogListResultDto`

#### Scenario: 拉取并缓存日志文件

- **假设** 客户端在线且返回文件列表
- **WHEN** 调用 `PullAndCacheAsync(input)`
- **THEN** 系统 SHALL 遍历 `input.Files` 数组
- **AND** 对每个文件调用 `HttpClient.GetAsync(http://{clientIP}:5900/api/local-log/download)`
- **AND** 验证响应成功（HTTP 200）
- **AND** 将文件流保存到 `ClientLogs/{ClientId}/{Date}/` 目录
- **AND** 创建 `ClientLog` 数据库记录
- **AND** 设置 `PulledAt` 为当前时间
- **AND** 返回 `List<ClientLogDto>`

#### Scenario: 获取已缓存日志列表

- **WHEN** 调用 `GetCachedLogsAsync(input)`
- **THEN** 系统 SHALL 查询 `ClientLog` 表
- **AND** 支持 `ClientId`、`LogDate`、`FileName` 过滤
- **AND** 支持分页（`SkipCount`、`MaxResultCount`）
- **AND** 返回 `PagedResultDto<ClientLogDto>`
- **AND** 按 `PulledAt` 降序排列

#### Scenario: 下载已缓存日志

- **假设** `id` 为有效的 `ClientLog.Id`
- **WHEN** 调用 `DownloadCachedAsync(id)`
- **THEN** 系统 SHALL 查询 `ClientLog` 记录
- **AND** 验证 `IsDeleted` 为 `false`
- **AND** 验证文件存在（`File.Exists(CachedFilePath)`）
- **AND** 返回 `PhysicalFileResult` 或 `FileStreamResult`
- **AND** 设置 Content-Type 为 `text/plain` 或 `application/octet-stream`
- **AND** 设置 `Content-Disposition: attachment; filename="{FileName}"`

#### Scenario: 批量下载（ZIP 打包）

- **假设** `ids` 包含 3 个有效的 `ClientLog.Id`
- **WHEN** 调用 `DownloadBatchCachedAsync(ids)`
- **THEN** 系统 SHALL 验证总大小不超过 `MaxZipSizeMB`
- **AND** 创建 `ZipArchive` 内存流
- **AND** 遍历每个 `ClientLog` 记录
- **AND** 读取文件流并添加到 ZIP
- **AND** ZIP 内文件名格式为 `{ClientId}_{OriginalFileName}`
- **AND** 返回 ZIP 文件流（`application/zip`）

#### Scenario: 删除已缓存日志

- **假设** `id` 为有效的 `ClientLog.Id`
- **WHEN** 调用 `DeleteCachedAsync(id)`
- **THEN** 系统 SHALL 查询 `ClientLog` 记录
- **AND** 删除物理文件（`File.Delete(CachedFilePath)`）
- **AND** 更新数据库记录：`IsDeleted = true`、`DeletedAt = DateTime.Now`、`DeletedBy = CurrentUser.UserName`
- **AND** 记录审计日志

### Requirement: ClientLog 实体

服务端必须定义客户端日志缓存实体。

#### Scenario: 实体字段定义

- **WHEN** 定义 `ClientLog` 实体
- **THEN** 系统 SHALL 继承 `FullAuditedEntity<Guid>`
- **AND** 包含 `ClientId` 字段（string，100 字符）
- **AND** 包含 `ClientName` 字段（string，200 字符）
- **AND** 包含 `FileName` 字段（string，200 字符）
- **AND** 包含 `OriginalFilePath` 字段（string，1000 字符）
- **AND** 包含 `CachedFilePath` 字段（string，1000 字符）
- **AND** 包含 `FileSize` 字段（long）
- **AND** 包含 `LogDate` 字段（DateTime）
- **AND** 包含 `ClientLastModified` 字段（DateTime）
- **AND** 包含 `PulledAt` 字段（DateTime）
- **AND** 包含 `IsDeleted` 字段（bool）
- **AND** 包含 `DeletedAt` 字段（DateTime? nullable）
- **AND** 包含 `DeletedBy` 字段（string? nullable）

#### Scenario: 实体约束

- **WHEN** 配置实体映射
- **THEN** `ClientId` 字段 SHALL 可索引
- **AND** `LogDate` 字段 SHALL 可索引
- **AND** `(ClientId, LogDate, FileName)` 组合 SHALL 唯一索引
- **AND** `IsDeleted` 字段 SHALL 默认为 `false`

### Requirement: ClientInfo 实体

服务端必须定义客户端连接信息实体。

#### Scenario: 实体字段定义

- **WHEN** 定义 `ClientInfo` 实体
- **THEN** 系统 SHALL 继承 `FullAuditedEntity<Guid>`
- **AND** 包含 `ClientId` 字段（string，100 字符，唯一）
- **AND** 包含 `ClientName` 字段（string，200 字符）
- **AND** 包含 `ClientVersion` 字段（string，50 字符）
- **AND** 包含 `LastConnectedAt` 字段（DateTime）
- **AND** 包含 `SignalRConnectionId` 字段（string? nullable）
- **AND** 包含 `IpAddress` 字段（string? nullable）
- **AND** 包含 `IsOnline` 字段（bool）
- **AND** 包含 `SupportsLogPull` 字段（bool）

### Requirement: ClientLogPullHistory 实体

服务端必须定义日志拉取审计实体。

#### Scenario: 实体字段定义

- **WHEN** 定义 `ClientLogPullHistory` 实体
- **THEN** 系统 SHALL 继承 `CreationAuditedEntity<Guid>`
- **AND** 包含 `ClientId` 字段（string，100 字符）
- **AND** 包含 `RequestDate` 字段（DateTime）
- **AND** 包含 `DateFolder` 字段（string，50 字符）
- **AND** 包含 `FilesJson` 字段（string，存储文件列表 JSON）
- **AND** 包含 `TotalSize` 字段（long）
- **AND** 包含 `PulledByUserId` 字段（Guid? nullable）
- **AND** 包含 `PulledByName` 字段（string? nullable）
- **AND** 包含 `PullIpAddress` 字段（string? nullable）
- **AND** 包含 `PullReason` 字段（string? nullable）
- **AND** 包含 `RelatedTicketId` 字段（string? nullable）
- **AND** 包含 `IsSuccess` 字段（bool）
- **AND** 包含 `ErrorMessage` 字段（string? nullable）

### Requirement: 权限控制

服务端必须实现细粒度权限控制，防止未授权访问。

#### Scenario: 定义权限常量

- **WHEN** 定义 `UrbanManagementPermissions` 类
- **THEN** 系统 SHALL 定义 `ClientLogs` 权限组
- **AND** 定义 `ClientLogs.Download` 权限（下载日志）
- **AND** 定义 `ClientLogs.Delete` 权限（删除缓存）
- **AND** 定义 `ClientLogs.Request` 权限（请求日志列表）

#### Scenario: 应用权限到 AppService

- **WHEN** 定义 `ClientLogAppService`
- **THEN** 系统 SHALL 使用 `[AbpAuthorize]` 属性
- **AND** `DownloadCachedAsync` 方法 SHALL 要求 `ClientLogs.Download` 权限
- **AND** `DeleteCachedAsync` 方法 SHALL 要求 `ClientLogs.Delete` 权限
- **AND** `RequestLogListAsync` 方法 SHALL 要求 `ClientLogs.Request` 权限
- **AND** 无权限用户 SHALL 收到 403 Forbidden

#### Scenario: 记录审计日志

- **WHEN** 用户下载日志
- **THEN** 系统 SHALL 创建 `ClientLogPullHistory` 记录
- **AND** 设置 `PulledByUserId` 为 `CurrentUser.Id`
- **AND** 设置 `PulledByName` 为 `CurrentUser.UserName`
- **AND** 设置 `PullIpAddress` 为请求来源 IP
- **AND** 设置 `IsSuccess` 为 `true`
- **AND** 下载失败时 SHALL 设置 `ErrorMessage`

### Requirement: 静态文件服务配置

服务端必须配置静态文件中间件，提供缓存文件下载。

#### Scenario: 配置静态文件映射

- **WHEN** UrbanManagement 应用启动
- **THEN** 系统 SHALL 配置 `UseStaticFiles()` 中间件
- **AND** 映射 `/ClientLogs/` 物理目录到 `{ContentRoot}/ClientLogs/`
- **AND** 设置 `FileServerOptions.DefaultFilesMode = DefaultFilesMode.None`
- **AND** 设置 `FileServerOptions.ServeUnknownFileTypes = true`

#### Scenario: 文件访问权限

- **WHEN** 请求 `/ClientLogs/{clientId}/{date}/{fileName}`
- **THEN** 系统 SHALL 验证用户已认证
- **AND** 验证用户拥有 `ClientLogs.Download` 权限
- **AND** 文件不存在时 SHALL 返回 404 Not Found
- **AND** 文件存在但已删除（`IsDeleted = true`）时 SHALL 返回 404 Not Found

### Requirement: 错误处理和超时

服务端必须处理各种异常情况和超时。

#### Scenario: 客户端离线

- **假设** `ClientId` 对应的客户端不在线
- **WHEN** 调用 `RequestLogListAsync()`
- **THEN** 系统 SHALL 等待响应超时（30 秒）
- **AND** 超时后 SHALL 抛出 `BusinessException`
- **AND** 错误消息包含 "客户端离线或未响应"
- **AND** 记录警告日志

#### Scenario: 文件拉取失败

- **假设** `HttpClient.GetAsync()` 返回非 200 状态码
- **WHEN** 拉取日志文件
- **THEN** 系统 SHALL 记录错误日志
- **AND** 跳过当前文件
- **AND** 继续处理下一个文件
- **AND** 返回部分成功结果
- **AND** 记录 `ClientLogPullHistory`（`IsSuccess = false`）

#### Scenario: 磁盘空间不足

- **假设** 写入缓存文件时磁盘空间不足
- **WHEN** 文件流写入
- **THEN** 系统 SHALL 捕获 `IOException`
- **AND** 记录错误日志（包含磁盘空间信息）
- **AND** 删除部分写入的文件
- **AND** 返回错误响应
- **AND** 不创建 `ClientLog` 记录

### Requirement: 配置管理

服务端行为必须可通过配置调整。

#### Scenario: 配置拉取限制

- **WHEN** 读取 `appsettings.json`
- **THEN** 系统 SHALL 识别 `ClientLogPull` 配置节
- **AND** 包含 `Enabled` 布尔值（默认 true）
- **AND** 包含 `MaxConcurrentPulls` 整数（默认 5）
- **AND** 包含 `PullTimeoutSeconds` 整数（默认 300）
- **AND** 包含 `MaxZipSizeMB` 整数（默认 500）
- **AND** 包含 `CacheBasePath` 字符串（默认 "ClientLogs/"）

#### Scenario: 配置缓存路径

- **WHEN** `CacheBasePath` 设置为 `D:/LogCache/`
- **THEN** 系统 SHALL 使用指定路径作为缓存根目录
- **AND** 路径不存在时 SHALL 自动创建
- **AND** 无权限时 SHALL 记录错误日志并使用默认路径
- **AND** 支持相对路径和绝对路径

### Requirement: 性能优化

服务端必须优化大文件传输和并发处理。

#### Scenario: 流式传输

- **假设** 日志文件大小为 50 MB
- **WHEN** `HttpClient.GetAsync()` 请求文件
- **THEN** 系统 SHALL 使用 `HttpCompletionOption.ResponseHeadersRead`
- **AND** 直接流式写入磁盘，不缓冲到内存
- **AND** 使用 64 KB 缓冲区
- **AND** 内存占用 SHALL 不超过 10 MB

#### Scenario: 并发拉取限制

- **假设** 用户同时请求拉取 10 个文件
- **WHEN** `PullAndCacheAsync()` 执行
- **THEN** 系统 SHALL 限制并发数为 `MaxConcurrentPulls`（默认 5）
- **AND** 超过限制时 SHALL 排队等待
- **AND** 记录性能日志
- **AND** 防止服务端资源耗尽

#### Scenario: 批量下载大小限制

- **假设** 用户请求打包 10 个文件，总大小 600 MB
- **WHEN** `DownloadBatchCachedAsync()` 执行
- **THEN** 系统 SHALL 计算总大小
- **AND** 超过 `MaxZipSizeMB` 时 SHALL 拒绝请求
- **AND** 返回错误响应（包含总大小和限制）
- **AND** 记录警告日志
