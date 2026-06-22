# Client Log Download Server Feature - Implementation Tasks

## 1. 客户端日志标准化（MaterialClient / MaterialClient.Urban）

- [ ] 1.1 更新 MaterialClient 日志配置：启用日期目录结构 `Logs/{YYYY}/{MM}/{DD}/`
- [ ] 1.2 更新 MaterialClient 日志配置：启用文件大小限制 `rollOnFileSizeLimit: true`，`fileSizeLimitBytes: 50MB`
- [ ] 1.3 更新 MaterialClient appsettings.json：新增 `Log` 配置节（`Enabled`、`Directory`、`FileSizeLimitMB`、`RetentionDays`、`UseDateFolders`）
- [ ] 1.4 更新 MaterialClient.Urban 日志配置：应用与 MaterialClient 相同的日期目录和大小限制
- [ ] 1.5 更新 MaterialClient.Urban appsettings.json：新增 `Log` 配置节
- [ ] 1.6 验证日志文件生成到正确路径：`Logs/2025/06/22/MaterialClient-20250622.log`
- [ ] 1.7 验证单文件超过 50MB 时自动切割为 `MaterialClient-20250622_001.log`

## 2. 客户端本地 HTTP API（MaterialClient.Urban）

- [ ] 2.1 创建 `LocalLogController` 类：`GET /api/local-log/download` 端点
- [ ] 2.2 创建 `LocalLogController` 类：`GET /api/local-log/list` 端点
- [ ] 2.3 实现文件下载逻辑：流式返回文件，支持断点续传（`Accept-Ranges: bytes`）
- [ ] 2.4 实现路径验证：防止目录遍历攻击（`..` 或绝对路径）
- [ ] 2.5 创建 `LogFileDto` 和 `LogCapabilityInfo` DTO 类
- [ ] 2.6 更新 MaterialClientUrbanModule：启动 Kestrel 监听 `localhost:5900`
- [ ] 2.7 更新 MaterialClientUrbanModule：配置控制器路由和依赖注入
- [ ] 2.8 更新 MaterialClient.Urban appsettings.json：新增 `LocalLogApi` 配置节（`Enabled`、`Port`）
- [ ] 2.9 测试本地 API：使用 curl 验证 `/api/local-log/list` 和 `/api/local-log/download` 端点

## 3. 客户端 SignalR 日志拉取服务（MaterialClient.Urban）

- [ ] 3.1 创建 `ClientLogPullService` 类：实现 `ITransientDependency` 接口
- [ ] 3.2 实现 `InitializeAsync` 方法：创建 HubConnection，配置 JWT AccessTokenProvider
- [ ] 3.3 实现 `InitializeAsync` 方法：注册 `ReceiveLogListRequest` 回调
- [ ] 3.4 实现 `InitializeAsync` 方法：连接成功后调用 `RegisterLogCapability` 注册能力
- [ ] 3.5 实现 `HandleLogListRequestAsync` 方法：扫描 `Logs/{dateFolder}` 目录
- [ ] 3.6 实现 `HandleLogListRequestAsync` 方法：构建 `ClientLogListResultDto` 响应
- [ ] 3.7 实现 `HandleLogListRequestAsync` 方法：调用 `ReturnLogList` 返回结果
- [ ] 3.8 更新 MaterialClientUrbanModule：应用关闭时调用 `ClientLogPullService.DisposeAsync`
- [ ] 3.9 更新 MaterialClient.Urban appsettings.json：新增 `UrbanManagement:BaseUrl` 和 `Client:Id` 配置
- [ ] 3.10 测试 SignalR 连接：验证客户端能成功连接并注册日志拉取能力

## 4. 服务端实体和 DbContext（UrbanManagement）

- [ ] 4.1 创建 `ClientLog` 实体类：继承 `FullAuditedEntity<Guid>`，定义字段（`ClientId`、`FileName`、`CachedFilePath`、`FileSize` 等）
- [ ] 4.2 创建 `ClientInfo` 实体类：继承 `FullAuditedEntity<Guid>`，定义字段（`ClientId`、`IsOnline`、`SignalRConnectionId` 等）
- [ ] 4.3 创建 `ClientLogPullHistory` 实体类：继承 `CreationAuditedEntity<Guid>`，定义字段（`ClientId`、`RequestDate`、`FilesJson`、`PulledByUserId` 等）
- [ ] 4.4 更新 `UrbanManagementDbContext`：添加 `DbSet<ClientLog>`、`DbSet<ClientInfo>`、`DbSet<ClientLogPullHistory>`
- [ ] 4.5 配置实体映射：`ClientId` 索引、`(ClientId, LogDate, FileName)` 唯一索引
- [ ] 4.6 创建 EF Core 迁移：`Add-Migration AddClientLogEntities`

## 5. 服务端 DTO 和模型（UrbanManagement）

- [ ] 5.1 创建 `ClientLogDto` 类：定义客户端日志 DTO（`FromEntity` 和 `ToEntity` 方法）
- [ ] 5.2 创建 `ClientInfoDto` 类：定义客户端信息 DTO
- [ ] 5.3 创建 `ClientLogListResultDto` 类：定义日志列表结果 DTO
- [ ] 5.4 创建 `RequestLogListDto` 类：定义请求日志列表输入 DTO
- [ ] 5.5 创建 `PullLogDto` 类：定义拉取日志输入 DTO
- [ ] 5.6 创建 `GetCachedLogsDto` 类：定义查询缓存日志输入 DTO
- [ ] 5.7 创建 `UrbanManagementPermissions` 扩展：添加 `ClientLogs`、`ClientLogsDownload`、`ClientLogsDelete`、`ClientLogsRequest` 权限常量

## 6. 服务端 SignalR Hub 扩展（UrbanManagement）

- [ ] 6.1 更新 `DeviceStatusHub`：新增 `RegisterLogCapability` 方法
- [ ] 6.2 更新 `DeviceStatusHub`：新增 `RequestLogList` 方法
- [ ] 6.3 更新 `DeviceStatusHub`：新增 `ReturnLogList` 方法
- [ ] 6.4 实现 `RegisterLogCapability` 方法：记录客户端能力到内存字典
- [ ] 6.5 实现 `RequestLogList` 方法：向客户端发送日志列表请求
- [ ] 6.6 实现 `ReturnLogList` 方法：将客户端响应转发到 HTTP 会话（Group "LogRequesters"）
- [ ] 6.7 测试 Hub 方法：使用 SignalR 测试客户端验证方法调用

## 7. 服务端应用服务（UrbanManagement）

- [ ] 7.1 创建 `ClientLogAppService` 类：继承 `ApplicationService`，实现 `IClientLogAppService`
- [ ] 7.2 实现 `GetOnlineClientsAsync` 方法：查询 `ClientInfo` 表（`IsOnline = true`）
- [ ] 7.3 实现 `RequestLogListAsync` 方法：调用 Hub 的 `RequestLogList`，等待响应（超时 30 秒）
- [ ] 7.4 实现 `PullAndCacheAsync` 方法：遍历文件列表，调用 `HttpClient` 下载
- [ ] 7.5 实现 `PullAndCacheAsync` 方法：保存文件到 `ClientLogs/{ClientId}/{Date}/` 目录
- [ ] 7.6 实现 `PullAndCacheAsync` 方法：创建 `ClientLog` 数据库记录
- [ ] 7.7 实现 `GetCachedLogsAsync` 方法：查询 `ClientLog` 表，支持分页和过滤
- [ ] 7.8 实现 `DownloadCachedAsync` 方法：返回文件流（`PhysicalFileResult`）
- [ ] 7.9 实现 `DownloadBatchCachedAsync` 方法：打包多个文件为 ZIP
- [ ] 7.10 实现 `DeleteCachedAsync` 方法：删除物理文件，更新 `IsDeleted` 标记
- [ ] 7.11 添加 `[AbpAuthorize]` 属性：应用 `ClientLogs.*` 权限到各方法
- [ ] 7.12 配置 Autofac：注册 `IClientLogAppService` 为瞬态服务

## 8. 服务端权限配置（UrbanManagement）

- [ ] 8.1 更新 `UrbanManagementPermissions` 类：添加 `ClientLogs` 权限组定义
- [ ] 8.2 更新 `UrbanManagementPermissionDefinitionProvider`：注册 `ClientLogs` 权限组
- [ ] 8.3 在数据库中创建权限：添加 `ClientLogs` 相关权限到角色

## 9. 服务端静态文件配置（UrbanManagement）

- [ ] 9.1 更新 `Program.cs` 或 `UrbanManagementAppModule`：配置 `UseStaticFiles()` 中间件
- [ ] 9.2 配置静态文件映射：映射 `/ClientLogs/` 到 `{ContentRoot}/ClientLogs/`
- [ ] 9.3 配置文件服务选项：`FileServerOptions.ServeUnknownFileTypes = true`
- [ ] 9.4 创建 `ClientLogs/` 目录：确保目录存在

## 10. 服务端配置（UrbanManagement）

- [ ] 10.1 更新 `appsettings.json`：新增 `ClientLogPull` 配置节
- [ ] 10.2 配置 `ClientLogPull:Enabled`：默认 `true`
- [ ] 10.3 配置 `ClientLogPull:MaxConcurrentPulls`：默认 `5`
- [ ] 10.4 配置 `ClientLogPull:PullTimeoutSeconds`：默认 `300`
- [ ] 10.5 配置 `ClientLogPull:MaxZipSizeMB`：默认 `500`
- [ ] 10.6 配置 `ClientLogPull:CacheBasePath`：默认 `ClientLogs/`
- [ ] 10.7 创建配置选项类：`ClientLogPullOptions`（`IOptions<ClientLogPullOptions>`）

## 11. Blazor 日志管理页面（UrbanManagement.App）

- [ ] 11.1 创建 `ClientLogManagement.razor` 页面：双栏布局（左侧控制，右侧列表）
- [ ] 11.2 实现在线客户端下拉框：调用 `GetOnlineClientsAsync`，显示 `ClientId` 和 `ClientName`
- [ ] 11.3 实现日期选择器：支持选择过去 30 天内日期
- [ ] 11.4 实现"查询日志列表"按钮：调用 `RequestLogListAsync`，显示加载动画
- [ ] 11.5 实现日志文件列表表格：显示文件名、大小、修改时间，支持多选
- [ ] 11.6 实现"拉取并缓存"按钮：调用 `PullAndCacheAsync`，显示进度对话框
- [ ] 11.7 实现已缓存日志列表：调用 `GetCachedLogsAsync`，显示分页表格
- [ ] 11.8 实现"下载"按钮：调用 `DownloadCachedAsync`，触发浏览器下载
- [ ] 11.9 实现"批量下载"按钮：调用 `DownloadBatchCachedAsync`，下载 ZIP 文件
- [ ] 11.10 实现"删除"按钮：显示确认对话框，调用 `DeleteCachedAsync`
- [ ] 11.11 添加权限检查：`AuthorizeView` 或 `IAuthorizationService` 检查 `ClientLogs` 权限
- [ ] 11.12 添加错误处理：显示错误通知（`ISnackbar` 或自定义通知组件）
- [ ] 11.13 添加菜单项：在主菜单中添加"客户端日志管理"入口

## 12. 单元测试（MaterialClient.Urban）

- [ ] 12.1 测试 `LocalLogController.DownloadLog` 方法：验证文件流返回
- [ ] 12.2 测试 `LocalLogController.DownloadLog` 方法：验证路径遍历防护
- [ ] 12.3 测试 `ClientLogPullService.HandleLogListRequestAsync` 方法：Mock 文件系统
- [ ] 12.4 测试 `ClientLogPullService.HandleLogListRequestAsync` 方法：验证响应格式

## 13. 单元测试（UrbanManagement）

- [ ] 13.1 测试 `DeviceStatusHub.RegisterLogCapability` 方法：验证内存字典更新
- [ ] 13.2 测试 `DeviceStatusHub.RequestLogList` 方法：Mock SignalR Group
- [ ] 13.3 测试 `ClientLogAppService.PullAndCacheAsync` 方法：Mock HttpClient
- [ ] 13.4 测试 `ClientLogAppService.GetCachedLogsAsync` 方法：Mock Repository
- [ ] 13.5 测试 `ClientLogAppService.DeleteCachedAsync` 方法：验证文件删除和数据库更新

## 14. 集成测试

- [ ] 14.1 端到端测试：启动 UrbanManagement 和 MaterialClient.Urban
- [ ] 14.2 测试完整流程：客户端注册能力 → 服务端请求列表 → 客户端返回列表 → 服务端拉取文件
- [ ] 14.3 测试离线场景：客户端离线时服务端请求列表超时
- [ ] 14.4 测试并发拉取：同时拉取 5 个文件，验证并发限制
- [ ] 14.5 测试大文件传输：拉取 50MB 日志文件，验证流式传输
- [ ] 14.6 测试批量下载：打包 3 个文件为 ZIP，验证 ZIP 内容

## 15. 部署和验证

- [ ] 15.1 部署客户端更新：更新 MaterialClient.Urban 到测试环境
- [ ] 15.2 验证客户端日志：检查 `Logs/{YYYY}/{MM}/{DD}/` 目录生成
- [ ] 15.3 验证本地 API：使用 curl 测试 `localhost:5900` 端点
- [ ] 15.4 验证 SignalR 连接：检查客户端成功连接 UrbanManagement
- [ ] 15.5 部署服务端更新：更新 UrbanManagement 到测试环境
- [ ] 15.6 运行数据库迁移：执行 `Update-Database`
- [ ] 15.7 验证权限：创建测试用户，分配 `ClientLogs` 权限
- [ ] 15.8 端到端验证：通过 Blazor UI 完整测试日志拉取流程
- [ ] 15.9 性能测试：拉取 100MB 日志文件，验证响应时间
- [ ] 15.10 安全测试：验证未授权用户无法访问日志功能
