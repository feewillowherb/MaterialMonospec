# Client Log Management UI Specification

## Purpose

定义 UrbanManagement Blazor 服务端的客户端日志管理界面要求，包括客户端选择、日期浏览、文件列表、缓存管理和批量下载功能。

## ADDED Requirements

### Requirement: 客户端日志管理页面入口

服务端必须在主菜单中提供"客户端日志管理"入口。

#### Scenario: 菜单导航

- **WHEN** 用户登录并拥有 `UrbanManagement.ClientLogs` 权限
- **THEN** 系统 SHALL 在侧边栏菜单中显示"客户端日志管理"菜单项
- **AND** 菜单图标为文件夹或日志图标
- **AND** 点击菜单项 SHALL 导航至 `/client-logs`
- **AND** 页面标题为"客户端日志管理"

#### Scenario: 权限检查

- **假设** 用户没有 `UrbanManagement.ClientLogs` 权限
- **WHEN** 用户尝试访问 `/client-logs`
- **THEN** 系统 SHALL 返回 403 Forbidden
- **AND** 显示"权限不足"错误提示
- **AND** 自动重定向至首页

### Requirement: 在线客户端列表

页面必须显示当前在线的客户端列表。

#### Scenario: 加载在线客户端

- **WHEN** 页面初始化
- **THEN** 系统 SHALL 调用 `GetOnlineClientsAsync()`
- **AND** 显示客户端列表（下拉框或列表）
- **AND** 每个客户端显示：
  - `ClientId`（如 "material-client-001"）
  - `ClientName`（如 "测试站点A"）
  - `LastConnectedAt`（如 "2025-06-22 14:30"）
  - 在线状态指示器（绿色圆点）
- **AND** 列表按 `LastConnectedAt` 降序排列

#### Scenario: 客户端离线提示

- **假设** 选中的客户端在操作过程中离线
- **WHEN** 用户点击"拉取日志"按钮
- **THEN** 系统 SHALL 显示错误提示
- **AND** 提示内容为"客户端已离线，无法拉取日志"
- **AND** 禁用"拉取日志"按钮
- **AND** 提供刷新按钮重新检查状态

#### Scenario: 客户端列表刷新

- **WHEN** 用户点击"刷新"按钮
- **THEN** 系统 SHALL 重新调用 `GetOnlineClientsAsync()`
- **AND** 更新客户端列表
- **AND** 保留当前选中的客户端（如仍在线）
- **AND** 显示加载动画

### Requirement: 日期选择器

页面必须提供日期选择器，指定要查询的日志日期。

#### Scenario: 日期选择

- **WHEN** 用户点击日期选择器
- **THEN** 系统 SHALL 显示日历控件
- **AND** 默认选中当前日期
- **AND** 支持选择过去 30 天内的日期
- **AND** 不允许选择未来日期

#### Scenario: 日期格式验证

- **WHEN** 用户选择日期
- **THEN** 系统 SHALL 验证日期格式
- **AND** 格式为 `YYYY-MM-DD`
- **AND** 自动转换为本时区的午夜时间（00:00:00）

### Requirement: 日志文件列表

页面必须显示选中客户端在指定日期的日志文件列表。

#### Scenario: 查询日志列表

- **假设** 用户已选择客户端和日期
- **WHEN** 用户点击"查询"按钮
- **THEN** 系统 SHALL 调用 `RequestLogListAsync(clientId, date)`
- **AND** 等待客户端响应（超时 30 秒）
- **AND** 显示加载动画（进度条或 Spinner）
- **AND** 超时时显示错误提示

#### Scenario: 显示文件列表

- **假设** 客户端返回 3 个日志文件
- **WHEN** 日志列表响应成功
- **THEN** 系统 SHALL 显示文件列表表格
- **AND** 每行包含：
  - 复选框（用于批量选择）
  - 文件名（如 "MaterialClient-20250622.log"）
  - 文件大小（如 "5.0 MB"）
  - 最后修改时间（如 "2025-06-22 23:59"）
- **AND** 表格支持多选（全选/反选）

#### Scenario: 文件列表为空

- **假设** 客户端返回空文件列表
- **WHEN** 日志列表响应成功
- **THEN** 系统 SHALL 显示"该日期无日志文件"提示
- **AND** 不显示表格
- **AND** 提示信息包含建议日期

#### Scenario: 文件大小格式化

- **假设** 文件大小为 52428800 字节（50 MB）
- **WHEN** 显示文件列表
- **THEN** 系统 SHALL 格式化文件大小
- **AND** 小于 1 MB 时显示 KB（如 "512.0 KB"）
- **AND** 1 MB - 1 GB 时显示 MB（如 "50.0 MB"）
- **AND** 超过 1 GB 时显示 GB（如 "1.2 GB"）
- **AND** 保留 1 位小数

### Requirement: 拉取并缓存功能

页面必须提供拉取选中文件并缓存到服务端的功能。

#### Scenario: 单文件拉取

- **假设** 用户选中 1 个文件
- **WHEN** 用户点击"拉取并缓存"按钮
- **THEN** 系统 SHALL 调用 `PullAndCacheAsync(clientId, selectedFiles)`
- **AND** 显示进度对话框（包含当前文件名和进度条）
- **AND** 拉取成功后 SHALL 显示"成功拉取 1 个文件"提示
- **AND** 自动刷新"已缓存日志"列表

#### Scenario: 批量文件拉取

- **假设** 用户选中 5 个文件
- **WHEN** 用户点击"拉取并缓存"按钮
- **THEN** 系统 SHALL 依次调用 `PullAndCacheAsync()`
- **AND** 显示进度对话框（显示"正在拉取 1/5..."）
- **AND** 支持取消操作（用户点击"取消"按钮）
- **AND** 所有文件拉取完成后 SHALL 显示"成功拉取 5 个文件"提示
- **AND** 部分失败时 SHALL 显示"成功拉取 4 个，失败 1 个"提示

#### Scenario: 拉取进度显示

- **假设** 文件大小为 50 MB
- **WHEN** 拉取进行中
- **THEN** 系统 SHALL 实时更新进度条
- **AND** 显示已传输字节数和总字节数
- **AND** 显示传输速度（如 "2.5 MB/s"）
- **AND** 预估剩余时间（如 "剩余 15 秒"）

#### Scenario: 拉取失败处理

- **假设** 客户端在拉取过程中离线
- **WHEN** `PullAndCacheAsync()` 抛出异常
- **THEN** 系统 SHALL 显示错误对话框
- **AND** 错误消息包含失败原因
- **AND** 提供重试按钮
- **AND** 提供取消按钮

### Requirement: 已缓存日志列表

页面必须显示已缓存在服务端的日志文件列表。

#### Scenario: 加载已缓存日志

- **WHEN** 页面初始化或刷新
- **THEN** 系统 SHALL 调用 `GetCachedLogsAsync()`
- **AND** 显示已缓存日志列表
- **AND** 每行包含：
  - 客户端名称（如 "material-client-001"）
  - 日志日期（如 "2025-06-22"）
  - 文件名（如 "MaterialClient-20250622.log"）
  - 文件大小（如 "5.0 MB"）
  - 拉取时间（如 "2025-06-22 14:30"）
  - 操作按钮（"下载"、"删除"）

#### Scenario: 分页显示

- **假设** 已缓存日志超过 50 条
- **WHEN** 显示已缓存日志列表
- **THEN** 系统 SHALL 启用分页
- **AND** 每页显示 20 条记录
- **AND** 提供页码导航（如 "1 2 3 ... 5"）
- **AND** 显示总记录数（如"共 85 条记录"）

#### Scenario: 过滤和排序

- **WHEN** 用户选择客户端或日期过滤
- **THEN** 系统 SHALL 重新调用 `GetCachedLogsAsync(input)`
- **AND** 更新已缓存日志列表
- **AND** 支持按拉取时间、文件大小排序

### Requirement: 下载已缓存日志

页面必须提供下载已缓存日志文件的功能。

#### Scenario: 单文件下载

- **假设** 用户点击"下载"按钮
- **WHEN** 下载请求发起
- **THEN** 系统 SHALL 调用浏览器下载 `GET /api/app/client-log/download/{id}`
- **AND** 浏览器 SHALL 弹出文件保存对话框
- **AND** 文件名为原始日志文件名

#### Scenario: 批量下载（ZIP）

- **假设** 用户选中 3 个已缓存日志
- **WHEN** 用户点击"批量下载"按钮
- **THEN** 系统 SHALL 调用 `DownloadBatchCachedAsync(ids)`
- **AND** 显示加载动画
- **AND** 浏览器 SHALL 下载 ZIP 文件
- **AND** ZIP 文件名为 `client-logs-{timestamp}.zip`

#### Scenario: 下载大小限制

- **假设** 用户请求下载总大小 600 MB 的日志
- **WHEN** 批量下载请求发起
- **THEN** 系统 SHALL 显示警告对话框
- **AND** 提示内容为"总大小 600 MB，超过限制 500 MB，请减少文件数量"
- **AND** 提供确定按钮关闭对话框

### Requirement: 删除已缓存日志

页面必须提供删除已缓存日志的功能。

#### Scenario: 单文件删除确认

- **假设** 用户点击"删除"按钮
- **WHEN** 删除请求发起
- **THEN** 系统 SHALL 显示确认对话框
- **AND** 对话框内容为"确定删除日志文件 MaterialClient-20250622.log？"
- **AND** 提供"确定"和"取消"按钮

#### Scenario: 执行删除操作

- **假设** 用户点击确认对话框的"确定"按钮
- **WHEN** 删除操作执行
- **THEN** 系统 SHALL 调用 `DeleteCachedAsync(id)`
- **AND** 显示删除进度动画
- **AND** 删除成功后 SHALL 显示"文件已删除"提示
- **AND** 自动刷新已缓存日志列表
- **AND** 从列表中移除已删除项

#### Scenario: 删除失败处理

- **假设** 删除操作失败（如文件被占用）
- **WHEN** `DeleteCachedAsync()` 抛出异常
- **THEN** 系统 SHALL 显示错误对话框
- **AND** 错误消息包含失败原因
- **AND** 提供重试按钮

### Requirement: UI 响应式设计

页面必须适配不同屏幕尺寸和设备。

#### Scenario: 桌面端显示

- **假设** 屏幕宽度 >= 1024 像素
- **WHEN** 页面渲染
- **THEN** 系统 SHALL 显示双栏布局
- **AND** 左侧为客户端列表和过滤器
- **AND** 右侧为日志文件列表和已缓存日志列表

#### Scenario: 平板端显示

- **假设** 屏幕宽度 768 - 1023 像素
- **WHEN** 页面渲染
- **THEN** 系统 SHALL 显示单栏布局
- **AND** 客户端列表折叠为下拉框
- **AND** 表格支持水平滚动

#### Scenario: 移动端显示

- **假设** 屏幕宽度 < 768 像素
- **WHEN** 页面渲染
- **THEN** 系统 SHALL 显示卡片式布局
- **AND** 每个日志文件显示为独立卡片
- **AND** 卡片包含文件名、大小、操作按钮
- **AND** 批量操作移至底部工具栏

### Requirement: 错误处理和用户反馈

页面必须提供清晰的错误提示和用户反馈。

#### Scenario: 网络错误提示

- **假设** API 调用失败（如 500 Internal Server Error）
- **WHEN** 错误响应返回
- **THEN** 系统 SHALL 显示错误通知
- **AND** 通知 SHALL 显示在页面右上角
- **AND** 包含错误消息和关闭按钮
- **AND** 自动消失（5 秒后）

#### Scenario: 加载状态显示

- **WHEN** 任何异步操作执行
- **THEN** 系统 SHALL 显示加载指示器
- **AND** 禁用相关按钮（防止重复提交）
- **AND** 操作完成后 SHALL 恢复按钮状态

#### Scenario: 操作成功反馈

- **WHEN** 任何写操作成功完成
- **THEN** 系统 SHALL 显示成功通知
- **AND** 通知 SHALL 显示操作结果（如"文件已拉取"）
- **AND** 自动消失（3 秒后）

### Requirement: 辅助功能和可访问性

页面必须符合可访问性标准。

#### Scenario: 键盘导航

- **WHEN** 用户使用 Tab 键导航
- **THEN** 系统 SHALL 支持键盘焦点移动
- **AND** 焦点顺序 SHALL 符合逻辑（从上到下，从左到右）
- **AND** Enter 键 SHALL 触发按钮点击

#### Scenario: 屏幕阅读器支持

- **WHEN** 屏幕阅读器读取页面
- **THEN** 系统 SHALL 提供 ARIA 标签
- **AND** 按钮 SHALL 包含 `aria-label` 属性
- **AND** 表格 SHALL 包含 `caption` 描述
- **AND** 错误提示 SHALL 关联到 `aria-live` 区域
