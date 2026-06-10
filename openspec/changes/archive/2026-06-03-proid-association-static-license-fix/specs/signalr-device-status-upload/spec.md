## MODIFIED Requirements

### Requirement: 设备状态消息协议

系统必须定义统一的设备状态消息格式，包含客户端标识、项目主键、项目展示名称、设备类型、状态值、时间戳等核心字段，并使用 JSON 序列化。

#### Scenario: 消息格式定义

- **WHEN** 构建设备状态消息
- **THEN** 消息必须为 `DeviceStatusMessage` record 类型
- **AND** 包含 `ClientId` 字段（string，客户端唯一标识）
- **AND** 包含 `ProId` 字段（string，项目主键，用于聚合和缓存，从 LicenseInfo.ProjectId 读取）
- **AND** 包含 `ProName` 字段（string，项目展示名称，从 LicenseInfo.ProName 读取）
- **AND** 包含 `DeviceType` 字段（string，设备类型如 "Scale"、"Camera"、"LPR"、"Sound"）
- **AND** 包含 `Status` 字段（string，状态值如 "Online"、"Offline"）
- **AND** 包含 `Timestamp` 字段（DateTime，状态变化时间）
- **AND** 包含 `AdditionalData` 字段（string? nullable，可选附加信息）

### Requirement: 设备状态上报

桌面端必须通过 ILocalEventBus 订阅设备状态变化事件，并将事件转换为包含 ProId 和 ProName 的 SignalR 消息发送至服务端。

#### Scenario: 处理设备状态事件

- **假设** 设备状态事件包含设备类型和在线状态
- **WHEN** `DeviceStatusEventHandler` 接收到 `StatusChangedEventData` 事件
- **THEN** 处理器 SHALL 从 `ILicenseService.GetCurrentLicenseAsync()` 读取 LicenseInfo
- **AND** 设置 `ProId` 为 `LicenseInfo.ProjectId.ToString()`（主键）
- **AND** 设置 `ProName` 为 `LicenseInfo.ProName`（展示名称）
- **AND** 设置 `ClientId` 为本地机器码或配置值
- **AND** 设置 `DeviceType` 为事件中的设备类型
- **AND** 设置 `Status` 为 "Online" 或 "Offline"
- **AND** 设置 `Timestamp` 为当前时间
- **AND** 调用 `DeviceStatusSignalRClient.UploadStatusAsync()`

### Requirement: 服务端状态处理

服务端必须提供 DeviceStatusService 处理接收到的设备状态消息，支持日志记录、消息分发和可选的持久化。

#### Scenario: 接收并验证消息

- **WHEN** DeviceStatusHub.UploadStatus() 方法被调用
- **THEN** 服务端 SHALL 验证消息格式合法性
- **AND** 当 ProId 非空时 SHALL 使用 ProId 作为聚合和缓存主键
- **AND** 当 ProId 为空时 SHALL 降级使用 ClientId 作为标识
- **AND** 验证失败时返回错误响应
- **AND** 验证成功时调用 DeviceStatusService
