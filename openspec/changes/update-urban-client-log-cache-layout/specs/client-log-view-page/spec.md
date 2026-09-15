## ADDED Requirements

### Requirement: 页面展示拉取错误明细

页面 MUST 在拉取过程出现错误或部分失败时，于页面内展示可读的错误信息，而不仅显示成功数量。

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

## MODIFIED Requirements

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
