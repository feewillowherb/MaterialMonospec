# ABP Typed Device Cache

## Purpose

Defines the requirements for implementing ABP typed distributed caching in the Urban Management system, replacing manual JSON serialization with strongly-typed cache items for device status, client registry, and connection state management.

## Requirements

### Requirement: CacheItem 类型定义

系统 MUST 定义 4 个 CacheItem 类作为 ABP 类型化缓存的泛型参数，所有类 MUST 位于 `UrbanManagement.Core.Models` 命名空间。

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

- **WHEN** 系统需要缓存已注册连接客户端 ID 集合（用于发现连接状态条目）
- **THEN** `ConnectionRegistryCacheItem` MUST 包含 `HashSet<string> ProIds` 属性，默认值为空集合
- **AND** 类 MUST 使用 `[CacheName("ConnectionRegistry")]` 属性声明缓存名称

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

`DeviceStatusService` MUST 注入类型化 `IDistributedCache<T>` 实例替代原始 `IDistributedCache`。

#### Scenario: 注入 4 个类型化缓存实例

- **WHEN** `DeviceStatusService` 被 DI 容器构造
- **THEN** MUST 注入 `IDistributedCache<DeviceStatusCacheItem>` 用于设备消息队列缓存
- **AND** MUST 注入 `IDistributedCache<ClientRegistryCacheItem>` 用于客户端发现注册表
- **AND** MUST 注入 `IDistributedCache<ClientConnectionCacheItem>` 用于连接状态缓存
- **AND** MUST 注入 `IDistributedCache<ConnectionRegistryCacheItem>` 用于连接发现注册表
- **AND** MUST NOT 注入原始 `IDistributedCache`

#### Scenario: 设备状态消息缓存写入

- **WHEN** `DeviceStatusService` 缓存一条新的设备状态消息
- **THEN** MUST 通过 `IDistributedCache<DeviceStatusCacheItem>.GetAsync(proId)` 读取现有队列
- **AND** MUST 将新消息追加到 `Messages` 列表
- **AND** MUST 在 `Messages.Count` 超过 100 时移除最早的条目（FIFO）
- **AND** MUST 通过 `IDistributedCache<DeviceStatusCacheItem>.SetAsync(proId, updatedItem)` 写回缓存
- **AND** MUST NOT 手动调用 `JsonSerializer.Serialize` 或 `JsonSerializer.Deserialize`

#### Scenario: 设备状态消息缓存读取

- **WHEN** `GetCachedMessagesAsync(clientId)` 被调用
- **THEN** MUST 通过 `IDistributedCache<DeviceStatusCacheItem>.GetAsync(key)` 读取缓存项
- **AND** 若缓存不存在 MUST 返回空列表

#### Scenario: 设备状态消息缓存清除

- **WHEN** `ClearCachedMessagesAsync(clientId)` 被调用
- **THEN** MUST 通过 `IDistributedCache<DeviceStatusCacheItem>.RemoveAsync(key)` 移除缓存项

#### Scenario: 客户端注册表更新

- **WHEN** 新的客户端 ProId 需要注册到客户端发现注册表
- **THEN** MUST 读取 `ClientRegistryCacheItem`，将 ProId 加入 `ProIds` 集合
- **AND** 仅在 ProId 为新增时写回缓存

#### Scenario: 连接状态缓存写入

- **WHEN** 客户端连接或断开时
- **THEN** MUST 通过 `IDistributedCache<ClientConnectionCacheItem>` 设置对应 ProId 的连接状态
- **AND** 连接时 MUST 设置 `IsConnected = true`、`ConnectedAt = DateTime.UtcNow`
- **AND** 断开时 MUST 设置 `IsConnected = false`、`DisconnectedAt = DateTime.UtcNow`

#### Scenario: 连接状态缓存读取

- **WHEN** `GetClientConnectionAsync(proId)` 被调用
- **THEN** MUST 通过 `IDistributedCache<ClientConnectionCacheItem>.GetAsync(proId)` 读取
- **AND** 若不存在 MUST 返回 `null`

### Requirement: DeviceStatusAppService 缓存访问统一

`DeviceStatusAppService` MUST 不再直接注入原始 `IDistributedCache`，缓存读取统一通过 `IDeviceStatusService` 或类型化缓存委托。

#### Scenario: 移除原始缓存注入

- **WHEN** `DeviceStatusAppService` 被 DI 容器构造
- **THEN** MUST NOT 注入原始 `IDistributedCache`
- **AND** 缓存数据读取 MUST 通过 `IDeviceStatusService` 接口方法或类型化 `IDistributedCache<T>` 获取

#### Scenario: 客户端设备聚合查询改用类型化缓存

- **WHEN** `GetClientDevicesAsync(proId)` 被调用
- **THEN** MUST 通过类型化 `IDistributedCache<DeviceStatusCacheItem>` 或 `IDeviceStatusService` 获取设备消息
- **AND** MUST NOT 手动调用 `GetStringAsync` + `JsonSerializer.Deserialize`

### Requirement: DeviceStatusHub 清理未使用依赖

`DeviceStatusHub` MUST 移除未使用的 `IDistributedCache` 注入。

#### Scenario: Hub 构造函数不含原始缓存

- **WHEN** `DeviceStatusHub` 被 DI 容器构造
- **THEN** 构造函数 MUST NOT 接受 `IDistributedCache` 参数
- **AND** 所有缓存操作 MUST 通过 `IDeviceStatusService` 委托（已满足）

### Requirement: 自定义 DateTime 转换器移除

系统 MUST 删除不再需要的自定义 JSON 序列化转换器。

#### Scenario: DateTimeJsonConverter 文件删除

- **WHEN** 重构完成
- **THEN** `DateTimeJsonConverter` 类和 `NullableDateTimeJsonConverter` 类 MUST 从代码库中删除
- **AND** `Tools/DateTimeJsonConverter.cs` 文件 MUST 被移除
