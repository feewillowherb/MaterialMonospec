# Device Status Query Specification

## Purpose

定义 UrbanManagement 设备状态查询能力，支持管理员通过 Web 页面查询和监控项目中设备的实时状态，包括设备列表查询、状态筛选、实时更新和历史记录查询（可选）。

## ADDED Requirements

### Requirement: 设备状态列表查询

UrbanManagement 应用必须提供设备状态查询 API，支持分页查询当前所有设备的在线状态，返回设备列表及总记录数。

#### Scenario: 查询所有设备状态

- **WHEN** 管理员调用 `GET /api/app/device-status/get-list` 且不提供任何筛选参数
- **THEN** 系统 SHALL 返回所有设备的最新状态列表
- **AND** 每个设备条目 SHALL 包含 ClientId、DeviceType、Status、LastUpdateTime、AdditionalData 字段
- **AND** 返回结果 SHALL 包含 TotalCount（总记录数）

#### Scenario: 查询结果分页

- **WHEN** 管理员调用查询 API 并提供 SkipCount=10、MaxResultCount=20
- **THEN** 系统 SHALL 跳过前 10 条记录
- **AND** 系统 SHALL 返回接下来的 20 条设备状态记录
- **AND** TotalCount SHALL 为所有记录的总数（不受分页影响）

#### Scenario: 按客户端ID筛选

- **WHEN** 管理员调用查询 API 并提供 ClientId="CLIENT-001"
- **THEN** 系统 SHALL 仅返回 ClientId 包含 "CLIENT-001" 的设备状态记录
- **AND** 筛选 SHALL 使用模糊匹配（Contains）

#### Scenario: 按设备类型筛选

- **WHEN** 管理员调用查询 API 并提供 DeviceType="Scale"
- **THEN** 系统 SHALL 仅返回 DeviceType 等于 "Scale" 的设备状态记录
- **AND** 筛选 SHALL 使用精确匹配

#### Scenario: 按状态筛选

- **WHEN** 管理员调用查询 API 并提供 Status="Online"
- **THEN** 系统 SHALL 仅返回 Status 等于 "Online" 的设备状态记录
- **AND** 筛选 SHALL 使用精确匹配

#### Scenario: 组合筛选条件

- **WHEN** 管理员调用查询 API 并同时提供 ClientId="CLIENT-001"、DeviceType="Scale"、Status="Online"
- **THEN** 系统 SHALL 应用所有筛选条件（AND 逻辑）
- **AND** 系统 SHALL 仅返回同时满足所有条件的设备状态记录

#### Scenario: 空筛选参数处理

- **WHEN** 管理员调用查询 API 并提供空字符串或 null 的筛选参数
- **THEN** 系统 SHALL 忽略该筛选条件
- **AND** 系统 SHALL 不抛出异常

### Requirement: 设备状态数据源

系统必须从分布式缓存中读取设备状态数据，聚合相同 ClientId 和 DeviceType 的最新状态，确保查询结果反映设备的当前状态。

#### Scenario: 从缓存读取设备状态

- **WHEN** 系统处理设备状态查询请求
- **THEN** 系统 SHALL 从 IDistributedCache 读取所有客户端的设备状态消息队列
- **AND** 系统 SHALL 使用缓存键格式 `device_status_cache:{ClientId}`

#### Scenario: 聚合相同设备的最新状态

- **WHEN** 缓存中存在同一 ClientId 和 DeviceType 的多条状态消息
- **THEN** 系统 SHALL 按 Timestamp 降序排序
- **AND** 系统 SHALL 仅返回最新的状态消息
- **AND** 系统 SHALL 忽略旧的状态消息

#### Scenario: 空缓存处理

- **WHEN** 分布式缓存中不存在任何设备状态数据
- **THEN** 系统 SHALL 返回空列表（Items 为空数组）
- **AND** TotalCount SHALL 为 0
- **AND** 系统 SHALL 不抛出异常

#### Scenario: 缓存数据反序列化失败

- **WHEN** 缓存中的 JSON 数据无法反序列化为 DeviceStatusMessage
- **THEN** 系统 SHALL 跳过该缓存键
- **AND** 系统 SHALL 记录警告日志
- **AND** 系统 SHALL 继续处理其他缓存键

### Requirement: 设备状态实时更新

Web 页面必须通过 SignalR 接收设备状态的实时推送更新，自动刷新表格中对应设备的显示状态。

#### Scenario: 建立 SignalR 连接

- **WHEN** 管理员打开设备管理页面
- **THEN** 页面 SHALL 自动建立与 DeviceStatusHub 的 SignalR 连接
- **AND** 连接 URL SHALL 为 `/hubs/devicestatus`
- **AND** 页面 SHALL 启用自动重连（`.withAutomaticReconnect()`）

#### Scenario: 订阅设备类型更新

- **WHEN** SignalR 连接成功建立
- **THEN** 页面 SHALL 对所有设备类型（Scale、Camera、LPR、Sound、Printer）调用 `SubscribeDeviceUpdates(deviceType)`
- **AND** 系统 SHALL 将连接加入对应的 SignalR 组

#### Scenario: 接收实时状态更新

- **WHEN** MaterialClient 上报新的设备状态消息
- **AND** 管理员的页面已订阅该设备类型
- **THEN** DeviceStatusHub SHALL 向页面发送 "DeviceStatusUpdate" 事件
- **AND** 页面 SHALL 接收 DeviceStatusMessage 消息
- **AND** 页面 SHALL 更新表格中对应的行

#### Scenario: 新增设备状态行

- **WHEN** 页面接收到的设备状态消息对应的 ClientId 和 DeviceType 在表格中不存在
- **THEN** 页面 SHALL 在表格中新增一行
- **AND** 新行 SHALL 包含该设备的所有状态信息

#### Scenario: 更新现有设备状态行

- **WHEN** 页面接收到的设备状态消息对应的 ClientId 和 DeviceType 在表格中已存在
- **THEN** 页面 SHALL 更新该行的状态、时间戳等信息
- **AND** 页面 SHALL 保持该行的位置（不重新排序）

#### Scenario: 更新最后心跳时间

- **WHEN** 页面接收到任何设备状态更新消息
- **THEN** 页面 SHALL 更新"最后心跳"时间显示
- **AND** 时间格式 SHALL 为 "刚刚" 或具体时间（如 "2秒前"）

#### Scenario: SignalR 连接断开处理

- **WHEN** SignalR 连接因网络问题断开
- **THEN** 页面 SHALL 尝试自动重连
- **AND** 页面 SHALL 显示连接状态指示器（红色或黄色）
- **AND** 页面 SHALL 停止接收实时更新

#### Scenario: SignalR 重连成功

- **WHEN** SignalR 连接重新建立
- **THEN** 页面 SHALL 重新订阅所有设备类型更新
- **AND** 页面 SHALL 显示连接状态指示器（绿色）
- **AND** 页面 SHALL 继续接收实时更新

### Requirement: 设备状态列表 UI 展示

Web 页面必须以表格形式展示设备状态列表，支持筛选、分页和状态指示器。

#### Scenario: 表格列定义

- **WHEN** 设备状态列表页面加载
- **THEN** 页面 SHALL 渲染表格，包含以下列：
  - **客户端ID** (ClientId)
  - **设备类型** (DeviceType)
  - **状态** (Status)
  - **最后更新时间** (LastUpdateTime)
  - **附加信息** (AdditionalData，可选)

#### Scenario: 状态指示器显示

- **WHEN** 设备状态为 "Online"
- **THEN** 状态列 SHALL 显示绿色圆点（🟢）和文字 "在线"
- **AND** 颜色 SHALL 使用 Bootstrap `text-success`

- **WHEN** 设备状态为 "Offline"
- **THEN** 状态列 SHALL 显示红色圆点（🔴）和文字 "离线"
- **AND** 颜色 SHALL 使用 Bootstrap `text-danger`

- **WHEN** 设备状态为 "Busy"
- **THEN** 状态列 SHALL 显示黄色圆点（🟡）和文字 "忙碌"
- **AND** 颜色 SHALL 使用 Bootstrap `text-warning`

#### Scenario: 设备类型标签显示

- **WHEN** 设备类型为 "Scale"
- **THEN** 设备类型列 SHALL 显示 "地磅 (Scale)"

- **WHEN** 设备类型为 "Camera"
- **THEN** 设备类型列 SHALL 显示 "摄像头 (Camera)"

- **WHEN** 设备类型为 "LPR"
- **THEN** 设备类型列 SHALL 显示 "车牌识别 (LPR)"

- **WHEN** 设备类型为 "Sound"
- **THEN** 设备类型列 SHALL 显示 "音响 (Sound)"

- **WHEN** 设备类型为 "Printer"
- **THEN** 设备类型列 SHALL 显示 "打印机 (Printer)"

#### Scenario: 时间格式化显示

- **WHEN** 最后更新时间为当前时间 1 分钟内
- **THEN** 时间列 SHALL 显示 "刚刚"

- **WHEN** 最后更新时间为当前时间 1 分钟到 1 小时
- **THEN** 时间列 SHALL显示 "X分钟前"（如 "5分钟前"）

- **WHEN** 最后更新时间超过 1 小时
- **THEN** 时间列 SHALL 显示完整日期时间格式（如 "2024-06-02 10:30:25"）

#### Scenario: 筛选 UI 组件

- **WHEN** 设备状态列表页面加载
- **THEN** 页面 SHALL 在表格上方显示筛选区域
- **AND** 筛选区域 SHALL 包含以下控件：
  - **设备类型** 下拉框（选项：全部、Scale、Camera、LPR、Sound、Printer）
  - **状态** 下拉框（选项：全部、Online、Offline、Busy）
  - **客户端ID** 文本输入框
  - **搜索** 按钮

#### Scenario: 分页 UI 组件

- **WHEN** 设备状态列表查询结果超过单页显示数量（默认 50 条）
- **THEN** 页面 SHALL 在表格下方显示分页控件
- **AND** 分页控件 SHALL 包含 "上一页"、"下一页" 和页码按钮
- **AND** 分页控件 SHALL 显示总记录数和当前页信息

#### Scenario: 实时更新状态指示器

- **WHEN** 设备状态列表页面加载
- **THEN** 页面 SHALL 在表格标题旁显示实时更新状态指示器
- **AND** SignalR 连接成功时，指示器 SHALL 显示绿色 "● 实时更新"
- **AND** SignalR 连接断开时，指示器 SHALL 显示红色 "● 连接断开"
- **AND** 指示器旁 SHALL 显示"最后心跳"时间

### Requirement: 设备状态查询 API 错误处理

系统必须正确处理查询 API 中的异常情况，返回适当的错误响应和日志记录。

#### Scenario: 无效的筛选参数

- **WHEN** 管理员提供无效的 DeviceType 值（不在预定义列表中）
- **THEN** 系统 SHALL 返回 400 Bad Request 错误
- **AND** 错误消息 SHALL 说明 "无效的设备类型"

- **WHEN** 管理员提供无效的 Status 值（不是 Online、Offline、Busy）
- **THEN** 系统 SHALL 返回 400 Bad Request 错误
- **AND** 错误消息 SHALL 说明 "无效的状态值"

#### Scenario: 分页参数验证

- **WHEN** 管理员提供负数的 SkipCount 或 MaxResultCount
- **THEN** 系统 SHALL 返回 400 Bad Request 错误
- **AND** 错误消息 SHALL 说明 "分页参数必须为正整数"

- **WHEN** 管理员提供的 MaxResultCount 超过 1000
- **THEN** 系统 SHALL 返回 400 Bad Request 错误
- **AND** 错误消息 SHALL 说明 "单次查询最多返回 1000 条记录"

#### Scenario: 缓存读取失败

- **WHEN** 分布式缓存服务不可用或超时
- **THEN** 系统 SHALL 返回 500 Internal Server Error 错误
- **AND** 系统 SHALL 记录错误日志
- **AND** 错误日志 SHALL 包含缓存键和异常详情

#### Scenario: 未授权访问

- **WHEN** 未登录的管理员尝试访问设备状态查询 API
- **THEN** 系统 SHALL 返回 401 Unauthorized 错误
- **AND** 系统 SHALL 重定向到登录页面

### Requirement: 设备状态查询性能

系统必须确保设备状态查询的性能满足响应时间要求，支持大量设备（1000+）的查询场景。

#### Scenario: 查询响应时间

- **WHEN** 设备总数不超过 100 个
- **THEN** 查询 API 的响应时间 SHALL 小于 500 毫秒（P95）

- **WHEN** 设备总数不超过 1000 个
- **THEN** 查询 API 的响应时间 SHALL 小于 2 秒（P95）

#### Scenario: 实时更新延迟

- **WHEN** MaterialClient 上报设备状态
- **THEN** Web 页面 SHALL 在 1 秒内接收到状态更新（P95）
- **AND** 延迟从 DeviceStatusHub 处理消息开始计算

#### Scenario: 内存使用控制

- **WHEN** 系统运行设备状态查询服务
- **THEN** 内存使用 SHALL 保持稳定，不出现内存泄漏
- **AND** 分布式缓存中的消息队列 SHALL 限制为每客户端最多 100 条（FIFO 清理）

### Requirement: 设备状态历史记录查询（可选）

系统可选支持设备状态历史记录查询，允许管理员查看设备在过去一段时间内的状态变化记录。

#### Scenario: 查询历史记录

- **WHEN** 管理员提供时间范围参数（StartTime、EndTime）
- **AND** 系统已启用 DeviceStatusLog 实体持久化
- **THEN** 系统 SHALL 从数据库查询该时间范围内的设备状态历史记录
- **AND** 系统 SHALL 按时间倒序返回记录

#### Scenario: 历史记录分页

- **WHEN** 历史记录总数超过单页显示数量
- **THEN** 系统 SHALL 支持分页查询
- **AND** 系统 SHALL 返回 TotalCount

#### Scenario: 未启用持久化

- **WHEN** 管理员请求查询历史记录
- **AND** 系统未启用 DeviceStatusLog 实体持久化
- **THEN** 系统 SHALL 返回 501 Not Implemented 错误
- **AND** 错误消息 SHALL 说明 "历史记录查询功能未启用"

## Success Criteria

- [ ] 管理员可访问 `/DeviceManagement/Index` 查看设备状态列表
- [ ] 查询 API `GET /api/app/device-status/get-list` 返回正确的设备状态数据
- [ ] 页面支持按设备类型、状态、客户端ID筛选
- [ ] 页面通过 SignalR 实时接收设备状态更新
- [ ] 设备状态数据准确反映 MaterialClient 上报的状态
- [ ] 查询响应时间满足性能要求（100 设备 < 500ms）
- [ ] SignalR 连接断开时自动重连
- [ ] 页面 UI 风格与现有 Project 页面保持一致
