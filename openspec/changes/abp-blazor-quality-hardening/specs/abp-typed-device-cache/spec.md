## MODIFIED Requirements

### Requirement: CacheItem 类型定义

系统 MUST 定义 4 个 CacheItem 类作为 ABP 类型化缓存的泛型参数，所有类 MUST 位于 `UrbanManagement.Core.Models` 命名空间。`ConnectionRegistryCacheItem` MUST 作为独立类型存在，用于管理连接发现注册表（与 `ClientRegistryCacheItem` 的客户端发现注册表语义分离）。

#### Scenario: DeviceStatusCacheItem 类结构

- **WHEN** 系统需要缓存某客户端的设备状态消息队列
- **THEN** `DeviceStatusCacheItem` MUST 包含 `List<DeviceStatusMessage> Messages` 属性，默认值为空列表
- **AND** 类 MUST 使用 `[CacheName("DeviceStatus")]` 属性声明缓存名称

#### Scenario: ClientRegistryCacheItem 类结构

- **WHEN** 系统需要缓存已注册客户端 ID 集合（用于发现哪些客户端有缓存数据）
- **THEN** `ClientRegistryCacheItem` MUST 包含 `HashSet<string> ProIds` 属性，默认值为空集合
- **AND** 类 MUST 使用 `[CacheName("ClientRegistry")]` 属性声明缓存名称

#### Scenario: ClientConnectionCacheItem 类结构

- **WHEN** 系统需要缓存单个客户端的 SignalR 连接状态
- **THEN** `ClientConnectionCacheItem` MUST 包含 `string ProId`、`string ProName`、`bool IsConnected`、`DateTime? ConnectedAt`、`DateTime? DisconnectedAt` 属性
- **AND** 类 MUST 使用 `[CacheName("ClientConnection")]` 属性声明缓存名称

#### Scenario: ConnectionRegistryCacheItem 类结构

- **WHEN** 系统需要缓存所有已连接客户端的 ProId 集合（用于发现哪些客户端当前/曾经建立过 SignalR 连接）
- **THEN** `ConnectionRegistryCacheItem` MUST 包含 `HashSet<string> ProIds` 属性，默认值为空集合
- **AND** 类 MUST 使用 `[CacheName("ConnectionRegistry")]` 属性声明缓存名称
- **AND** MUST 作为独立类型存在，MUST NOT 与 `ClientRegistryCacheItem` 共享 `[CacheName]`

### Requirement: ABP 缓存模块集成

系统 MUST 在 `UrbanManagementCoreModule` 中集成 ABP 缓存模块并配置缓存策略。

#### Scenario: 模块依赖声明

- **WHEN** `UrbanManagementCoreModule` 初始化
- **THEN** 模块 MUST 在 `[DependsOn]` 中声明对 `AbpCachingModule` 的依赖
- **AND** `UrbanManagement.Core.csproj` MUST 引用 `Volo.Abp.Caching` NuGet 包

#### Scenario: 按类型配置缓存过期策略

- **WHEN** `UrbanManagementCoreModule.ConfigureServices` 执行
- **THEN** 系统 MUST 通过 `Configure<AbpDistributedCacheOptions>` 配置各缓存类型的过期策略
- **AND** `DeviceStatusCacheItem` MUST 配置 `AbsoluteExpirationRelativeToNow` 为 24 小时
- **AND** `ClientConnectionCacheItem` MUST 配置 `AbsoluteExpirationRelativeToNow` 为 24 小时
- **AND** `ClientRegistryCacheItem` MUST 配置 `AbsoluteExpirationRelativeToNow` 为 25 小时
- **AND** `ConnectionRegistryCacheItem` MUST 配置 `AbsoluteExpirationRelativeToNow` 为 25 小时
- **AND** `KeyPrefix` MUST 设置为 `"UM:"`

### Requirement: DeviceStatusService 类型化缓存注入

`DeviceStatusService` MUST 注入 4 个类型化 `IDistributedCache<T>` 实例，每个注册表使用独立的 CacheItem 类型。

#### Scenario: 注入 4 个类型化缓存实例

- **WHEN** `DeviceStatusService` 被 DI 容器构造
- **THEN** MUST 注入 `IDistributedCache<DeviceStatusCacheItem>` 用于设备消息队列缓存
- **AND** MUST 注入 `IDistributedCache<ClientRegistryCacheItem>` 用于客户端发现注册表（缓存键 `"__registry__"`）
- **AND** MUST 注入 `IDistributedCache<ClientConnectionCacheItem>` 用于连接状态缓存
- **AND** MUST 注入 `IDistributedCache<ConnectionRegistryCacheItem>` 用于连接发现注册表（缓存键 `"__connection_registry__"`）
- **AND** MUST NOT 注入原始 `IDistributedCache`

#### Scenario: 连接注册表使用 ConnectionRegistryCacheItem

- **WHEN** `DeviceStatusService` 需要读写连接发现注册表
- **THEN** MUST 通过 `IDistributedCache<ConnectionRegistryCacheItem>` 使用缓存键 `"__connection_registry__"` 读写
- **AND** MUST NOT 使用 `ClientRegistryCacheItem` 类型管理连接注册表

#### Scenario: 设备状态消息缓存写入

- **WHEN** `DeviceStatusService` 缓存一条新的设备状态消息
- **THEN** MUST 通过 `IDistributedCache<DeviceStatusCacheItem>.GetAsync(proId)` 读取现有队列
- **AND** MUST 将新消息追加到 `Messages` 列表
- **AND** MUST 在 `Messages.Count` 超过 100 时移除最早的条目（FIFO）
- **AND** MUST 通过 `IDistributedCache<DeviceStatusCacheItem>.SetAsync(proId, updatedItem)` 写回缓存

#### Scenario: 连接状态缓存写入

- **WHEN** 客户端连接或断开时
- **THEN** MUST 通过 `IDistributedCache<ClientConnectionCacheItem>` 设置对应 ProId 的连接状态
- **AND** 连接时 MUST 设置 `IsConnected = true`、`ConnectedAt = DateTime.UtcNow`
- **AND** 断开时 MUST 设置 `IsConnected = false`、`DisconnectedAt = DateTime.UtcNow`
- **AND** MUST 同时更新连接发现注册表（使用 `IDistributedCache<ConnectionRegistryCacheItem>` 缓存键 `"__connection_registry__"`）

### Requirement: DeviceStatusAppService 缓存访问统一

`DeviceStatusAppService` MUST NOT 注入任何 `IDistributedCache<T>` 实例。所有缓存数据读取 MUST 通过 `IDeviceStatusService` 接口方法获取。

#### Scenario: 移除所有缓存注入

- **WHEN** `DeviceStatusAppService` 被 DI 容器构造
- **THEN** MUST NOT 注入原始 `IDistributedCache`
- **AND** MUST NOT 注入 `IDistributedCache<DeviceStatusCacheItem>`
- **AND** MUST NOT 注入 `IDistributedCache<ClientRegistryCacheItem>`
- **AND** MUST NOT 注入 `IDistributedCache<ClientConnectionCacheItem>`
- **AND** MUST NOT 注入 `IDistributedCache<ConnectionRegistryCacheItem>`

#### Scenario: GetClientDevicesAsync 通过 Service 委托

- **WHEN** `GetClientDevicesAsync(proId)` 被调用
- **THEN** MUST 通过 `IDeviceStatusService.GetDeviceMessagesAsync(proId)` 获取设备消息列表
- **AND** MUST NOT 直接调用 `IDistributedCache<T>.GetAsync`

#### Scenario: GetAllDeviceStatusFromCacheAsync 通过 Service 委托

- **WHEN** `GetAllDeviceStatusFromCacheAsync` 被调用
- **THEN** MUST 通过 `IDeviceStatusService.GetAllCachedClientIdsAsync()` 获取注册表
- **AND** MUST 通过 `IDeviceStatusService.GetCachedMessagesAsync(key)` 获取每个客户端的消息
- **AND** MUST NOT 直接调用 `IDistributedCache<T>.GetAsync`

#### Scenario: 注册表查询迭代上限保护

- **WHEN** `GetListAsync` 或 `GetClientListAsync` 读取注册表缓存中的 ProIds 集合
- **THEN** 若 `ProIds.Count` 超过 500 MUST 记录警告日志并截断到前 500 条
- **AND** MUST NOT 无限制遍历所有 ProIds

## ADDED Requirements

### Requirement: IDeviceStatusService 接口扩展

`IDeviceStatusService` MUST 新增 `GetDeviceMessagesAsync` 方法，供 `DeviceStatusAppService` 委托查询缓存数据。

#### Scenario: GetDeviceMessagesAsync 方法签名

- **WHEN** `IDeviceStatusService` 接口定义
- **THEN** MUST 包含 `Task<List<DeviceStatusMessage>> GetDeviceMessagesAsync(string proId)` 方法
- **AND** 该方法 MUST 返回指定 ProId 的缓存设备消息列表（可能为空列表）
