# client-log-http-upload Specification

## Purpose
TBD - created by archiving change refactor-client-log-http-zip-upload. Update Purpose after archive.
## Requirements
### Requirement: 2.0 SignalR 控制指令触发 HTTP Zip 流式上传

服务端在拉取 2.0 客户端指定日期日志时，SHALL 通过 SignalR 下发控制指令并由客户端通过 HTTP multipart 流式上传 `.zip` 压缩包，不再通过 SignalR 分片传输大文件。

#### Scenario: 2.0 客户端按日期打包并流式上传日志
- **WHEN** 管理员对已注册 2.0 日志上传能力的在线客户端发起 `PullLogsByDateAsync(clientId, dateFolder)`
- **THEN** 服务端 SHALL 生成唯一的 `requestId` 与一次性随机 `uploadToken`
- **AND** 服务端 SHALL 通过 SignalR 向该客户端连接发送 `ReceiveLogUploadRequest(requestId, clientId, dateFolder, uploadPath, uploadToken)`
- **AND** 客户端 SHALL 使用 `ClientLogScanner` 扫描目标日期 `.log` 文件并打包为本地临时 `.zip`
- **AND** 客户端 SHALL 通过 HTTP POST `multipart/form-data` 将临时 `.zip` 流式上传至 `{UrbanManagement:BaseUrl}{uploadPath}`
- **AND** 服务端 SHALL 校验 `uploadToken` 与 `clientId` 后流式落盘并解压至 `ClientLogs/{SafeProName}/{ClientId}/`
- **AND** 客户端与服务端 SHALL 在完成后清理各自临时 `.zip` 文件

#### Scenario: 0 字节日志文件与空日期目录处理
- **WHEN** 目标日期目录包含 0 字节 `.log` 文件
- **THEN** 客户端 SHALL 将该 0 字节文件正常打入 `.zip` 并在服务端成功解压落盘，不得挂死或超时
- **WHEN** 目标日期目录无任何 `.log` 文件
- **THEN** 客户端 SHALL 向上传端点回报 `fileCount = 0` 使服务端立即返回空结果而不等待超时

### Requirement: 路径边界与一次性令牌安全校验

客户端与服务端在处理远程日志上传与解压时，SHALL 强制执行路径边界校验与一次性令牌校验。

#### Scenario: 客户端拒绝路径穿越请求
- **WHEN** `dateFolder` 包含 `..`、绝对路径或解析后超出 `Path.GetFullPath(logBaseDirectory)` 边界
- **THEN** 客户端 SHALL 拒绝扫描与打包并向服务端回报失败原因

#### Scenario: 服务端拒绝非法或重复使用的上传令牌及 Zip Slip 条目
- **WHEN** `POST /api/client-log/upload-zip` 收到缺失、无效、过期或已消费的 `uploadToken`
- **THEN** 服务端 SHALL 返回 HTTP 401/403 且不写入磁盘
- **WHEN** 上传的 `.zip` 包含试图越出 `ClientLogs/{SafeProName}/{ClientId}/` 根目录的条目
- **THEN** 服务端 SHALL 跳过或拒绝该越界条目，不得写入缓存根目录之外

### Requirement: 批量下载流式打包与安全临时文件清理

服务端在批量打包下载已缓存日志时，SHALL 避免整包 `MemoryStream` 内存缓冲并安全清理临时 ZIP。

#### Scenario: 批量下载使用流式写盘与 DeleteOnClose
- **WHEN** 管理员调用 `POST /api/client-log/download-batch`
- **THEN** 服务端 SHALL 直接将 ZIP 内容写入临时磁盘文件（不调用 `MemoryStream.ToArray()`）
- **AND** `ClientLogController.DownloadBatch` SHALL 以 `FileOptions.DeleteOnClose` 打开文件流返回，不得在返回流前的 `finally` 中调用 `File.Delete`

### Requirement: 1.0 客户端向后兼容

在 1.0 客户端退网前，服务端 SHALL 保持对 1.0 客户端的日志拉取兼容。

#### Scenario: 1.0 客户端回退旧分片通道
- **WHEN** 目标客户端仅通过 1.0 `RegisterLogCapability` 注册且 `LogFormatVersion != "2.0"`
- **THEN** 服务端 SHALL 回退执行既有 `RequestLogListAsync` + `PullAndCacheAsync` 流程，不抛出协议不兼容错误

