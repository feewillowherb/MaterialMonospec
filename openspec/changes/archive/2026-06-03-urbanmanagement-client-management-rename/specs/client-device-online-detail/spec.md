## ADDED Requirements

### Requirement: 客户端设备在线详情页视图

UrbanManagement.App MUST 提供 `Views/ClientManagement/Detail.cshtml` 页面，以客户端为维度聚合展示该客户端下所有设备类型的实时在线状态。

#### Scenario: 详情页基本布局

- **WHEN** 用户访问 `/ClientManagement/Detail?id={proId}`
- **THEN** 页面 SHALL 显示客户端标识（ProName 或 ProId）
- **AND** SHALL 显示"返回列表"导航链接（指向 `/ClientManagement/Index`）
- **AND** SHALL 使用 `Layout = null`（独立页面，与列表页一致）

#### Scenario: 五种设备类型的在线状态卡片

- **WHEN** 详情页加载完成
- **THEN** 页面 SHALL 展示 5 个设备类型卡片：地磅 (Scale)、摄像头 (Camera)、车牌识别 (LPR)、音响 (Sound)、打印机 (Printer)
- **AND** 每个卡片 SHALL 显示设备类型名称、在线状态（颜色编码）、最后更新时间

#### Scenario: 在线状态颜色编码

- **WHEN** 设备状态为 Online
- **THEN** 该设备卡片 SHALL 显示绿色指示器（🟢）和"在线"文本

- **WHEN** 设备状态为 Offline
- **THEN** 该设备卡片 SHALL 显示红色指示器（🔴）和"离线"文本

- **WHEN** 设备状态为 Busy
- **THEN** 该设备卡片 SHALL 显示黄色指示器（🟡）和"忙碌"文本

- **WHEN** 该设备类型无任何上报记录
- **THEN** 该设备卡片 SHALL 显示灰色指示器（⚪）和"未上报"文本

### Requirement: 详情页数据加载

详情页 MUST 通过 HTTP API 获取初始数据，同时通过浏览器端 SignalR 接收实时设备状态更新。

#### Scenario: 初始数据加载

- **WHEN** 详情页加载且 URL 中包含有效的 `id` 参数
- **THEN** 页面 SHALL 调用 `GET /api/app/device-status/client-devices?proId={proId}`
- **AND** 根据返回数据渲染各设备类型的状态卡片

#### Scenario: API 响应结构

- **WHEN** 调用 `GetClientDevicesAsync` 接口
- **THEN** 返回值 SHALL 为包含各设备类型最新状态的列表
- **AND** 每项 SHALL 包含 DeviceType、Status、LastUpdateTime 字段
- **AND** 按设备类型聚合，每个设备类型仅保留最新一条记录

#### Scenario: 无效 id 参数

- **WHEN** 详情页 URL 中 `id` 参数为空
- **THEN** 页面 SHALL 显示错误提示信息
- **AND** SHALL NOT 发起 API 请求

#### Scenario: 客户端无数据

- **WHEN** API 返回空结果（该 ProId 无缓存数据）
- **THEN** 所有 5 个设备类型卡片 SHALL 均显示"未上报"状态

### Requirement: 详情页实时更新

详情页 MUST 通过浏览器端 SignalR 实时更新当前客户端的设备在线状态。

#### Scenario: SignalR 连接建立

- **WHEN** 详情页加载完成
- **THEN** 页面 SHALL 建立 SignalR 连接至 `/hubs/devicestatus`
- **AND** SHALL 订阅所有设备类型的更新（Scale, Camera, LPR, Sound, Printer）

#### Scenario: 实时状态更新过滤

- **WHEN** SignalR 收到 `DeviceStatusUpdate` 事件
- **THEN** 页面 SHALL 检查消息的 ProId 是否匹配当前页面 URL 中的 id 参数
- **AND** 匹配时 SHALL 更新对应设备类型卡片的状态和时间
- **AND** 不匹配时 SHALL 忽略该消息

#### Scenario: 连接状态指示器

- **WHEN** 详情页 SignalR 连接状态发生变化
- **THEN** 页面 SHALL 显示连接状态指示器（实时更新 / 连接断开 / 重连中）
- **AND** 显示最后心跳时间

#### Scenario: 断线降级轮询

- **WHEN** 浏览器与 UrbanManagement 之间的 SignalR 连接断开
- **THEN** 详情页 SHALL 启动 30 秒间隔的轮询调用 `GET /api/app/device-status/client-devices?proId={proId}` 作为降级方案
- **AND** SignalR 重连成功后 SHALL 停止轮询

#### Scenario: MaterialClient SignalR 断开期间的状态陈旧

- **WHEN** MaterialClient 与 UrbanManagement 之间的 SignalR 连接断开
- **THEN** 详情页 SHALL 继续显示断开前最后一次缓存的设备状态
- **AND** SHALL NOT 将设备状态自动变更为"离线"
- **AND** 通过每个设备卡片的"最后更新时间"让运维人员判断数据的新鲜程度

### Requirement: GetClientDevicesAsync API 方法

DeviceStatusAppService MUST 新增 `GetClientDevicesAsync` 方法，按指定 ProId 从分布式缓存中查询该客户端所有设备类型的最新状态。

#### Scenario: 按客户端聚合查询

- **WHEN** 调用 `GetClientDevicesAsync(proId)` 方法
- **THEN** 服务 SHALL 从分布式缓存读取 `device_status_cache:{proId}` 的数据
- **AND** SHALL 按 DeviceType 分组
- **AND** SHALL 取每组中 Timestamp 最新的记录
- **AND** SHALL 返回聚合后的结果列表

#### Scenario: ProId 为空

- **WHEN** `proId` 参数为空或空白
- **THEN** 方法 SHALL 抛出 `BusinessException`
- **AND** 错误码为 `UM:DeviceStatus:ProIdRequired`

#### Scenario: 缓存无数据

- **WHEN** 指定 ProId 的缓存中无数据
- **THEN** 方法 SHALL 返回空列表（不抛异常）

#### Scenario: API 路由注册

- **WHEN** UrbanManagement 应用启动
- **THEN** ABP 自动路由 SHALL 将 `GetClientDevicesAsync` 暴露为 `GET /api/app/device-status/client-devices`
- **AND** 参数 `proId` SHALL 通过 query string 传入
