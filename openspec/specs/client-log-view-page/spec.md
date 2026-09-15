# Client Log View Page Specification

## Purpose

定义 UrbanManagement 管理后台的客户端日志管理页面，提供日志查询、拉取、缓存、下载和删除功能。

## Requirements

### Requirement: 客户端日志管理页面路由和导航入口

系统必须在主菜单中提供"客户端日志"导航入口，并支持路由 `/client-logs`。

#### Scenario: 侧边栏菜单显示

- **WHEN** UrbanManagement 应用加载完成
- **THEN** 系统 SHALL 在 `AdminLayout.razor` 的 `_navItems` 列表中包含 `("/client-logs", "客户端日志")` 导航项
- **AND** 菜单项排列在"异常审批"之后
- **AND** 点击菜单项 SHALL 导航至 `/client-logs`

#### Scenario: 页面路由绑定

- **WHEN** 用户直接访问 `/client-logs` 路由
- **THEN** 系统 SHALL 渲染 `ClientLogs.razor` 组件
- **AND** 页面标题为"客户端日志管理"
- **AND** 页面在标签栏中显示为"客户端日志"

### Requirement: 在线客户端下拉选择

页面必须提供客户端下拉选择器，显示当前已注册日志拉取能力的在线客户端列表。

#### Scenario: 加载在线客户端列表

- **WHEN** `ClientLogs.razor` 组件初始化
- **THEN** 系统 SHALL 调用 `GetOnlineClientsAsync()` 获取在线客户端列表
- **AND** 将列表填充到下拉选择器
- **AND** 每个选项显示 `ClientId`
- **AND** 下拉选择器默认无选中项，显示占位文本"选择客户端"

#### Scenario: 无在线客户端

- **假设** 当前没有客户端在线
- **WHEN** 页面初始化
- **THEN** 系统 SHALL 显示下拉选择器，但选项列表为空
- **AND** 下拉选择器 SHALL 显示占位文本"暂无在线客户端"
- **AND** 查询按钮 SHALL 保持可用（但不触发实际查询）

#### Scenario: 刷新客户端列表

- **WHEN** 用户点击页面右上角的"刷新"按钮
- **THEN** 系统 SHALL 重新调用 `GetOnlineClientsAsync()`
- **AND** 更新下拉选择器选项
- **AND** 保留当前选中的客户端（如仍在线）
- **AND** 显示加载状态

### Requirement: 日期选择器

页面必须提供日期选择器，用于指定查询的日志日期目录。

#### Scenario: 日期选择

- **WHEN** 用户点击日期输入框
- **THEN** 系统 SHALL 显示原生日期选择器控件
- **AND** 默认选中当前日期
- **AND** 不限制日期范围

#### Scenario: 日期格式转换

- **假设** 用户选择了 2025-06-22
- **WHEN** 用户点击查询按钮
- **THEN** 系统 SHALL 将日期转换为 `DateFolder` 格式 `2025/06/22/`
- **AND** 传递给 `RequestLogListAsync` 的 `DateFolder` 参数

### Requirement: 查询客户端日志列表

页面必须提供查询功能，从指定客户端获取指定日期的日志文件列表。

#### Scenario: 发起查询

- **假设** 用户已选择客户端和日期
- **WHEN** 用户点击"查询日志"按钮
- **THEN** 系统 SHALL 调用 `RequestLogListAsync(new RequestLogListDto { ClientId, DateFolder })`
- **AND** 禁用查询按钮（防止重复提交）
- **AND** 在日志文件表格区域显示加载动画

#### Scenario: 查询成功

- **假设** 客户端返回 3 个日志文件
- **WHEN** `RequestLogListAsync` 返回成功
- **THEN** 系统 SHALL 在日志文件表格中显示 3 行数据
- **AND** 每行包含：复选框、文件名、文件大小（格式化为 KB/MB/GB）、最后修改时间
- **AND** 恢复查询按钮状态
- **AND** 清空文件选择状态

#### Scenario: 查询超时

- **假设** 客户端在 30 秒内未响应
- **WHEN** `RequestLogListAsync` 抛出 `TimeoutException`
- **THEN** 系统 SHALL 在页面顶部显示错误提示"查询超时，客户端可能已离线"
- **AND** 恢复查询按钮状态

#### Scenario: 客户端未注册

- **假设** 选中的客户端未注册日志拉取能力
- **WHEN** `RequestLogListAsync` 抛出 `UserFriendlyException`
- **THEN** 系统 SHALL 显示错误提示消息内容
- **AND** 恢复查询按钮状态

### Requirement: 日志文件表格和多选

页面必须支持多选日志文件进行批量操作。

#### Scenario: 显示文件大小

- **假设** 文件大小为 5242880 字节
- **WHEN** 显示日志文件表格
- **THEN** 系统 SHALL 格式化文件大小为 "5.0 MB"
- **AND** 小于 1MB 显示 KB，1MB-1GB 显示 MB，超过 1GB 显示 GB
- **AND** 保留 1 位小数

#### Scenario: 全选和取消全选

- **WHEN** 用户点击表头复选框
- **THEN** 系统 SHALL 切换所有文件行的选中状态
- **AND** 更新"已选 N 项"计数显示

#### Scenario: 单文件选择

- **WHEN** 用户点击某行的复选框
- **THEN** 系统 SHALL 切换该行的选中状态
- **AND** 更新"已选 N 项"计数显示

#### Scenario: 无文件时显示空状态

- **假设** 查询结果无文件
- **WHEN** 日志文件列表为空
- **THEN** 系统 SHALL 在表格区域显示空状态提示"该日期无日志文件"
- **AND** 不显示表格和操作按钮

### Requirement: 页面展示拉取错误明细

页面 MUST 在拉取过程出现错误或部分失败时，于页面内展示可读的错误信息，而不仅显示成功数量。服务端应用日志中的失败明细由 `server-log-pull-api` 保证；页面展示与日志 MUST 均可看到失败原因。

#### Scenario: 一键拉取部分失败展示明细

- **假设** `PullLogsByDateAsync` 返回 `PulledCount` 小于 `TotalFilesFound` 且 `Failures` 非空
- **WHEN** 拉取完成回到 `ClientLogs.razor`
- **THEN** 系统 SHALL 在页面错误/结果区域显示汇总（例如成功数与失败数）
- **AND** SHALL 列出每个失败项的文件名与原因
- **AND** 不得仅显示成功计数而隐藏失败原因

#### Scenario: 选择性拉取失败展示明细

- **假设** `PullAndCacheAsync` 返回的结果中 `Failures` 非空
- **WHEN** 选择性拉取完成
- **THEN** 系统 SHALL 在页面展示失败文件名与原因
- **AND** 若仍有成功文件，SHALL 同时提示成功数量并刷新已缓存目录视图

#### Scenario: 整批异常仍展示页面错误

- **假设** 拉取抛出超时或 `UserFriendlyException`
- **WHEN** 异常被捕获
- **THEN** 系统 SHALL 在页面顶部（或既有 alert 区域）显示错误文案
- **AND** 恢复按钮可用状态

### Requirement: 已缓存目录单击打开查看

页面已缓存区域 MUST 支持按目录层次单击进入查看内容。

#### Scenario: 根目录显示项目文件夹

- **WHEN** 用户打开或刷新已缓存区域且当前路径为根
- **THEN** 系统 SHALL 调用浏览 API 列出 ProName（项目）目录
- **AND** 遗留缓存入口（如 `_legacy`）SHALL 可见（若存在遗留文件）
- **AND** 目录行可单击

#### Scenario: 单击目录进入下一层

- **假设** 当前列表中有目录「萧山项目A」
- **WHEN** 用户单击该目录行
- **THEN** 系统 SHALL 将当前路径推进到该目录
- **AND** 重新加载并显示其下 ClientId（或下一层）条目
- **AND** 面包屑或返回上级控件 SHALL 可用

#### Scenario: 在目录中查看文件并下载

- **假设** 用户已进入含 `.log` 文件的目录
- **WHEN** 列表显示文件行
- **THEN** 系统 SHALL 显示文件名、大小等基本信息
- **AND** 用户 SHALL 能对该文件执行既有下载/删除操作

#### Scenario: 返回上级目录

- **假设** 当前路径非根
- **WHEN** 用户点击「上级」或面包屑中的父级
- **THEN** 系统 SHALL 回退一层并重新加载该层条目

### Requirement: 一键拉取到服务器

页面 MUST 在查询条件面板中提供"拉取到服务器"按钮，允许管理员一键将指定客户端指定日期的全部日志文件拉取到服务端磁盘；结果与错误 MUST 在页面展示。

#### Scenario: 一键拉取

- **假设** 用户已选择客户端和日期
- **WHEN** 用户点击"拉取到服务器"按钮
- **THEN** 系统 SHALL 调用 `PullLogsByDateAsync(clientId, dateFolder)` 服务端 API
- **AND** 显示加载状态"正在拉取 {clientId} {date} 的日志..."
- **AND** 服务端完成拉取后显示结果（成功数、失败明细或"该日期无日志文件"）
- **AND** 自动刷新已缓存目录视图

#### Scenario: 一键拉取时未选择客户端

- **WHEN** 未选择客户端
- **THEN** "拉取到服务器"按钮 SHALL 处于禁用状态

#### Scenario: 一键拉取时未选择日期

- **WHEN** 未选择日期
- **THEN** "拉取到服务器"按钮 SHALL 处于禁用状态

#### Scenario: 一键拉取期间按钮禁用

- **WHEN** 正在拉取或查询中
- **THEN** "拉取到服务器"按钮和"查询日志"按钮 SHALL 均处于禁用状态

#### Scenario: 一键拉取失败

- **假设** 客户端离线或拉取超时
- **WHEN** `PullLogsByDateAsync` 抛出异常
- **THEN** 系统 SHALL 显示错误提示（"拉取超时，客户端可能已离线"或异常消息）

### Requirement: 选择性拉取并缓存日志文件

页面 MUST 提供将已查询的指定文件从客户端拉取到服务端磁盘的功能，通过服务端 API 执行拉取，并在页面展示失败明细。

#### Scenario: 选择性拉取

- **假设** 用户已查询日志列表并选中文件
- **WHEN** 用户点击"拉取并缓存"按钮
- **THEN** 系统 SHALL 调用 `PullAndCacheAsync(PullLogDto)` 服务端 API，传递选中的文件列表
- **AND** 服务端通过 SignalR 直接从客户端拉取文件并写入 `ClientLogs/{ProName}/{ClientId}/...`
- **AND** 显示加载状态"正在拉取 N 个文件到服务器..."
- **AND** 拉取完成后显示结果提示（含成功数；若有失败则含失败明细）
- **AND** 自动刷新已缓存目录视图
- **AND** 清空文件选择状态

#### Scenario: 部分拉取失败

- **假设** 选中 3 个文件，其中 1 个拉取失败
- **WHEN** `PullAndCacheAsync` 返回部分成功结果
- **THEN** 系统 SHALL 显示成功与失败汇总
- **AND** SHALL 展示失败文件的原因

#### Scenario: 未选择文件时禁用按钮

- **WHEN** 未选择任何文件
- **THEN** "拉取并缓存"按钮 SHALL 处于禁用状态

#### Scenario: 拉取期间按钮禁用

- **WHEN** 正在拉取中
- **THEN** "拉取并缓存"按钮 SHALL 处于禁用状态

### Requirement: 已缓存日志列表

页面 MUST 提供已缓存在服务端的日志目录浏览与文件操作入口（目录单击打开查看），不再仅以无层级扁平表作为唯一视图。

#### Scenario: 加载已缓存根目录

- **WHEN** 页面初始化或拉取完成后
- **THEN** 系统 SHALL 调用浏览 API 加载已缓存根目录
- **AND** 显示可单击的目录条目（ProName / 遗留入口）
- **AND** 提供刷新当前目录的能力

#### Scenario: 已缓存列表为空

- **WHEN** 根目录无任何缓存
- **THEN** 系统 SHALL 显示空状态提示"暂无已缓存的日志文件"
- **AND** 不显示目录表格

#### Scenario: 文件层保留下载删除

- **假设** 当前目录含文件条目
- **WHEN** 显示文件行
- **THEN** 每行 SHALL 提供"下载"与"删除"（及既有批量操作，若该层多选启用）

### Requirement: 下载已缓存日志

页面必须提供下载已缓存日志文件的功能。

#### Scenario: 单文件下载

- **WHEN** 用户点击某行的"下载"按钮
- **THEN** 系统 SHALL 通过浏览器打开 `GET /api/client-log/download/{id}`
- **AND** 浏览器 SHALL 触发文件下载
- **AND** 下载文件名为原始日志文件名

#### Scenario: 批量下载 ZIP

- **假设** 用户选中 2 个已缓存日志
- **WHEN** 用户点击"批量下载 ZIP"按钮
- **THEN** 系统 SHALL 收集选中文件的 ID
- **AND** 通过浏览器请求 `POST /api/client-log/download-batch`
- **AND** 浏览器 SHALL 下载 ZIP 文件
- **AND** ZIP 文件名为 `client-logs-{timestamp}.zip`

#### Scenario: 下载大小超限

- **假设** 选中文件总大小超过 500MB
- **WHEN** 用户点击"批量下载 ZIP"
- **THEN** 系统 SHALL 显示警告提示"总大小超过限制 500MB，请减少文件数量"
- **AND** 不发起下载请求

### Requirement: 删除已缓存日志

页面必须提供删除已缓存日志文件的功能。

#### Scenario: 单文件删除确认

- **WHEN** 用户点击某行的"删除"按钮
- **THEN** 系统 SHALL 显示确认对话框
- **AND** 对话框内容为"确定删除日志文件 {FileName}？"
- **AND** 提供"确定"和"取消"按钮

#### Scenario: 确认删除

- **WHEN** 用户点击确认对话框的"确定"按钮
- **THEN** 系统 SHALL 调用 `DeleteCachedAsync(id)`
- **AND** 显示操作中的加载状态
- **AND** 删除成功后显示提示"文件已删除"
- **AND** 从列表中移除已删除项
- **AND** 自动刷新已缓存列表

#### Scenario: 批量删除

- **假设** 用户选中多个已缓存日志
- **WHEN** 用户点击"批量删除"按钮
- **THEN** 系统 SHALL 显示确认对话框"确定删除选中的 N 个日志文件？"
- **AND** 用户确认后 SHALL 调用 `DeleteBatchCachedAsync(ids)`
- **AND** 成功后刷新列表并显示提示

### Requirement: 页面加载和刷新

页面必须在初始化时加载必要数据，并提供手动刷新功能。

#### Scenario: 初始加载

- **WHEN** `ClientLogs.razor` 组件初始化
- **THEN** 系统 SHALL 并行执行：
  1. 加载在线客户端列表 (`GetOnlineClientsAsync`)
  2. 加载已缓存日志列表 (`GetCachedLogsAsync`)
- **AND** 加载期间显示全局加载动画
- **AND** 所有数据加载完成后隐藏加载动画

#### Scenario: 手动刷新

- **WHEN** 用户点击页面标题栏的"刷新"按钮
- **THEN** 系统 SHALL 重新加载在线客户端列表和已缓存日志列表
- **AND** 保留当前选中的客户端和日期
- **AND** 保留日志文件查询结果（不清空）
