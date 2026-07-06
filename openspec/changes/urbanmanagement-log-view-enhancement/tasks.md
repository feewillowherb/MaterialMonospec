## 1. 后端基础设施补全

- [x] 1.1 在 `DeviceStatusHub.cs` 中新增 `GetAllLogCapabilities()` 公共静态方法，加锁读取 `_logCapabilityRegistry` 并返回 `List<ClientInfoDto>`
- [x] 1.2 在 `ClientLogAppService.cs` 中完善 `GetOnlineClientsAsync()`，调用 `DeviceStatusHub.GetAllLogCapabilities()` 替代空列表返回
- [x] 1.3 在 `ClientLogInputDtos.cs` 中新增 `SaveCachedFileDto`，包含 `ClientId`、`FilePath`、`FileName`、`FileContent`（base64 字符串）属性
- [x] 1.4 在 `IClientLogAppService.cs` 接口中新增 `SaveCachedFileAsync(SaveCachedFileDto dto)` 方法签名
- [x] 1.5 在 `ClientLogAppService.cs` 中实现 `SaveCachedFileAsync`：base64 解码 → 创建目录 → 写入文件 → 更新 `_pathMap`

## 2. 后端下载和删除方法实现

- [x] 2.1 在 `ClientLogAppService.cs` 中将 `_pathMap` 改为 `static readonly ConcurrentDictionary<Guid, string>`，并在 `GetCachedLogsAsync` 中填充映射（使用路径 SHA256 哈希前 16 字节生成确定性 Guid）
- [x] 2.2 完善 `DownloadCachedAsync(Guid id)`：从 `_pathMap` 查找路径 → 验证文件存在 → 返回 `FileDownloadResultDto`；文件不存在时清理 `_pathMap` 并抛出异常
- [x] 2.3 实现 `DownloadBatchCachedAsync(DownloadBatchInputDto input)`：查找所有路径 → 计算总大小 → 超 500MB 拒绝 → 创建 `ZipArchive` → 逐文件添加到 ZIP → 返回 `FileDownloadResultDto`（ContentType = application/zip）
- [x] 2.4 实现 `DeleteCachedAsync(Guid id)`：从 `_pathMap` 查找路径 → `File.Delete` → 移除 `_pathMap` 条目 → 尝试删除空父目录
- [x] 2.5 实现 `DeleteBatchCachedAsync(Guid[] ids)`：遍历执行单文件删除 → 跳过无效 Id → 返回成功删除计数

## 3. 下载 Controller

- [x] 3.1 在 `src/UrbanManagement.App/Controllers/` 下新建 `ClientLogController.cs`，继承 `ControllerBase`，路由 `[Route("api/client-log")]`
- [x] 3.2 实现 `GET download/{id:guid}` 端点：注入 `IClientLogAppService` → 调用 `DownloadCachedAsync` → 读取文件流 → 返回 `FileStreamResult`（设置 Content-Disposition attachment）
- [x] 3.3 实现 `POST download-batch` 端点：从请求体读取 `LogIds` → 调用 `DownloadBatchCachedAsync` → 读取 ZIP MemoryStream → 返回 `FileStreamResult`
- [x] 3.4 在 `UrbanManagementAppModule.cs` 中确认 `ClientLogController` 被注册（ABP 自动注册或手动 `AddControllers`）

## 4. 前端页面 — ClientLogs.razor 基础结构

- [x] 4.1 在 `src/UrbanManagement.App/Pages/` 下新建 `ClientLogs.razor`，添加 `@page "/client-logs"` 指令、服务注入（`IClientLogAppService`、`IJSRuntime`、`NavigationManager`）
- [x] 4.2 实现页面整体 HTML 结构：`layui-fluid > layui-card`，包含标题栏（含刷新按钮）、查询条件面板、日志文件表格区域、已缓存日志表格区域
- [x] 4.3 实现 `@code` 部分的状态字段声明：客户端列表、选中客户端、选中日期、日志文件列表、已缓存列表、分页参数、加载状态、选中文件集合等

## 5. 前端页面 — 在线客户端选择和查询

- [x] 5.1 实现在线客户端下拉选择器：`<select>` 绑定 `_selectedClientId`，`<option>` 遍历 `_clients`，默认空选项
- [x] 5.2 实现日期选择器：`<input type="date">` 绑定 `_selectedDate`
- [x] 5.3 实现"查询日志"按钮点击事件：构造 `RequestLogListDto`（将日期转换为 `YYYY/MM/DD/` 格式）→ 调用 API → 填充 `_logFiles` 列表 → 处理异常
- [x] 5.4 实现"刷新"按钮：重新加载客户端列表和已缓存列表，保留当前选择

## 6. 前端页面 — 日志文件表格和拉取

- [x] 6.1 实现日志文件表格：`data-table` 布局，列包含全选复选框、文件名、文件大小（格式化方法）、修改时间
- [x] 6.2 实现文件多选逻辑：`_selectedLogFiles` HashSet，全选/单选切换，"已选 N 项"计数显示
- [x] 6.3 实现"拉取并缓存"按钮：检查选中文件 → 初始化 SignalR HubConnection → 加入 `LogRequesters` 组 → 逐文件发起拉取
- [x] 6.4 实现 SignalR 文件分块接收回调 `OnReceiveFileChunk`：累积到 `MemoryStream` → 所有分块完成后调用 `SaveCachedFileAsync` → 更新进度弹窗
- [x] 6.5 实现拉取进度弹窗（modal）：显示当前文件名、分块进度 N/M、取消按钮
- [x] 6.6 实现拉取完成后的状态更新：刷新已缓存列表、显示成功/部分失败提示、清空文件选择

## 7. 前端页面 — 已缓存日志列表

- [x] 7.1 实现已缓存日志表格：`data-table` 布局，列包含客户端 ID、日期、文件名、文件大小、拉取时间、操作按钮
- [x] 7.2 实现已缓存列表分页：`GetCachedLogsAsync` + 分页 UI（复用现有 pagination 组件模式）
- [x] 7.3 实现已缓存文件多选：复选框选择、"批量下载 ZIP"、"批量删除"按钮
- [x] 7.4 实现单文件下载：点击下载按钮 → `NavigationManager.NavigateTo("/api/client-log/download/{id}", forceLoad: true)` 触发浏览器下载
- [x] 7.5 实现批量 ZIP 下载：收集选中 Id → 构造 fetch POST 请求 → 创建 Blob URL → 触发浏览器下载 → 清理 Blob URL
- [x] 7.6 实现单文件删除确认弹窗（modal）：显示文件名 → 确认后调用 `DeleteCachedAsync` → 刷新列表
- [x] 7.7 实现批量删除确认弹窗：显示选中数量 → 确认后调用 `DeleteBatchCachedAsync` → 刷新列表

## 8. 导航入口和样式

- [x] 8.1 在 `AdminLayout.razor` 的 `_navItems` 列表中添加 `new("/client-logs", "客户端日志")` 导航项（放在"异常审批"之后）
- [x] 8.2 在 `components.css` 中新增日志页面专用样式：双栏筛选面板布局、操作工具栏、批量操作按钮组、进度条样式
- [x] 8.3 验证页面在侧边栏显示正确，点击可导航，标签页标题为"客户端日志"

## 9. 验证和清理

- [x] 9.1 编译 UrbanManagement 解决方案，确认无编译错误
- [x] 9.2 检查所有新增和修改文件，确认代码风格与现有代码一致（file-scoped namespaces、nullable 引用类型、ABP 约定）
- [x] 9.3 确认 `ClientLogAppService` 的 `NotImplementedException` 方法已全部替换为实际实现
- [x] 9.4 确认 SignalR Hub 连接、文件传输、断连处理的关键路径覆盖
