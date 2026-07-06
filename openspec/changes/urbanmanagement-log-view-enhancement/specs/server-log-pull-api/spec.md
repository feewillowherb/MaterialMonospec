## MODIFIED Requirements

### Requirement: DeviceStatusHub 日志方法扩展

服务端必须扩展现有 DeviceStatusHub，新增日志拉取相关方法。

#### Scenario: 注册日志拉取能力

- **假设** 客户端调用 `RegisterLogCapability(clientId, capability)`
- **WHEN** 方法执行
- **THEN** 系统 SHALL 验证 `clientId` 非空
- **AND** 验证 `capability.SupportsLogPull` 为 `true`
- **AND** 记录客户端日志拉取能力到内存字典 `_logCapabilityRegistry`
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
- **AND** 调用 `ClientLogAppService.TryCompleteLogListRequest(result)` 完成 HTTP 侧等待
- **AND** 调用 `Clients.Group("LogRequesters").SendAsync("LogListResponse", result)` 转发到订阅组
- **AND** 记录调试日志

#### Scenario: 获取所有已注册日志能力的客户端列表

- **WHEN** 外部代码调用 `DeviceStatusHub.GetAllLogCapabilities()` 静态方法
- **THEN** 系统 SHALL 加锁读取 `_logCapabilityRegistry`
- **AND** 返回 `List<ClientInfoDto>`，每个元素包含 `ClientId`、`ClientName`（等于 ClientId）、`LastConnectedAt`（等于注册时间）、`SupportsLogPull`
- **AND** 按 `LastConnectedAt` 降序排列

### Requirement: ClientLogAppService 服务

服务端必须提供客户端日志应用服务，处理日志列表查询、拉取和缓存管理。

#### Scenario: 获取在线客户端列表

- **WHEN** 调用 `GetOnlineClientsAsync()`
- **THEN** 系统 SHALL 调用 `DeviceStatusHub.GetAllLogCapabilities()` 静态方法
- **AND** 返回 `List<ClientInfoDto>`
- **AND** 包含 `ClientId`、`ClientName`、`LastConnectedAt`、`SupportsLogPull` 字段

#### Scenario: 请求客户端日志列表

- **假设** `input.ClientId` 为 "material-client-001"，`input.DateFolder` 为 "2025/06/22/"
- **WHEN** 调用 `RequestLogListAsync(input)`
- **THEN** 系统 SHALL 生成唯一 `requestId`（GUID）
- **AND** 通过 `IHubContext<DeviceStatusHub>` 调用 `Clients.Client(connectionId).SendAsync("ReceiveLogListRequest", requestId, clientId, dateFolder)`
- **AND** 等待 `TaskCompletionSource<ClientLogListResultDto>` 响应（超时 30 秒）
- **AND** 返回 `ClientLogListResultDto`

#### Scenario: 保存已缓存文件

- **假设** Blazor 页面将完整的文件内容通过 `SaveCachedFileDto` 传递
- **WHEN** 调用 `SaveCachedFileAsync(SaveCachedFileDto dto)`
- **THEN** 系统 SHALL 验证 `dto.ClientId` 和 `dto.FileName` 非空
- **AND** 将 base64 解码为字节数组
- **AND** 创建目标目录 `ClientLogs/{ClientId}/{FilePath}/`
- **AND** 将字节数组写入 `{目标目录}/{FileName}`
- **AND** 更新内部路径映射 `_pathMap`
- **AND** 返回 `true`

#### Scenario: 获取已缓存日志列表

- **WHEN** 调用 `GetCachedLogsAsync(input)`
- **THEN** 系统 SHALL 扫描 `ClientLogs/` 目录下的所有子目录
- **AND** 查找所有 `.log` 文件
- **AND** 支持 `ClientId` 过滤
- **AND** 为每个文件生成确定性 Guid（基于路径 SHA256 哈希前 16 字节）
- **AND** 填充 `_pathMap` 映射
- **AND** 返回 `PagedResultDto<CachedLogFileDto>`
- **AND** 按 `LastModifiedUtc` 降序排列

#### Scenario: 下载已缓存日志

- **假设** `id` 为有效的缓存日志 Guid
- **WHEN** 调用 `DownloadCachedAsync(id)`
- **THEN** 系统 SHALL 从 `_pathMap` 查找对应的文件物理路径
- **AND** 验证文件存在（`File.Exists(path)`）
- **AND** 返回 `FileDownloadResultDto`，包含 `FilePath`、`ContentType`（"application/octet-stream"）、`FileName`

#### Scenario: 批量下载（ZIP 打包）

- **假设** `input.LogIds` 包含 3 个有效的 Guid
- **WHEN** 调用 `DownloadBatchCachedAsync(input)`
- **THEN** 系统 SHALL 从 `_pathMap` 查找每个 Guid 对应的文件路径
- **AND** 计算所有文件的总大小
- **AND** 总大小超过 500MB 时 SHALL 抛出 `UserFriendlyException`，消息包含总大小和限制
- **AND** 创建 `MemoryStream` 和 `ZipArchive`
- **AND** 遍历每个文件，读取文件流并添加到 ZIP
- **AND** ZIP 内文件名格式为 `{ClientId}/{OriginalFileName}`
- **AND** 返回 `FileDownloadResultDto`，`ContentType` 为 "application/zip"，`FileName` 为 `client-logs-{timestamp}.zip`

#### Scenario: 删除已缓存日志

- **假设** `id` 为有效的缓存日志 Guid
- **WHEN** 调用 `DeleteCachedAsync(id)`
- **THEN** 系统 SHALL 从 `_pathMap` 查找对应的文件物理路径
- **AND** 验证文件存在
- **AND** 调用 `File.Delete(path)` 删除物理文件
- **AND** 从 `_pathMap` 中移除该 Guid
- **AND** 尝试删除空目录（不抛异常）

#### Scenario: 批量删除已缓存日志

- **假设** `ids` 包含 3 个有效的 Guid
- **WHEN** 调用 `DeleteBatchCachedAsync(ids)`
- **THEN** 系统 SHALL 遍历每个 Guid
- **AND** 对每个有效 Guid 执行单文件删除逻辑
- **AND** 跳过无效 Guid（不抛异常）
- **AND** 返回成功删除的文件数量

#### Scenario: 下载不存在的文件

- **假设** `id` 在 `_pathMap` 中存在但文件已被手动删除
- **WHEN** 调用 `DownloadCachedAsync(id)`
- **THEN** 系统 SHALL 从 `_pathMap` 中移除该 Guid
- **AND** 抛出 `UserFriendlyException("文件不存在")`
