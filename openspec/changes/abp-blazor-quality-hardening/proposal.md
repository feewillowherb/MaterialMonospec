## Why

UrbanManagement 完成了 ABP Blazor 架构迁移后，缓存层存在三个质量问题：（1）`DeviceStatusAppService` 绕过 `IDeviceStatusService` 直接访问 `IDistributedCache<T>`，破坏了服务边界；（2）`Models/` 目录混放了 CacheItem、DTO、Message 三类模型，缺乏按职责的子目录划分；（3）`DeviceStatusService` 内部用同一个 `ClientRegistryCacheItem` 类型承载 `__registry__` 和 `__connection_registry__` 两个语义不同的注册表，职责模糊。本次变更聚焦 UrbanManagement 仓库内部的质量加固。

## What Changes

- **消除 AppService 直连缓存**：将 `DeviceStatusAppService` 中的 `IDistributedCache<DeviceStatusCacheItem>` 注入替换为对 `IDeviceStatusService` 的委托调用，使缓存读写全部收敛到 service 层。
- **拆分 Models/ 子目录**：在 `UrbanManagement.Core/Models/` 下建立 `Cache/`、`Dtos/`、`Messages/` 三个子目录，将现有文件按职责迁移，更新所有命名空间引用。
- **统一注册表缓存语义**：将 `ClientRegistryCacheItem` 的双重用途（client discovery registry + connection registry）拆分为独立的 `ConnectionRegistryCacheItem` 类型，还原两个注册表的语义清晰度。

## Capabilities

### New Capabilities

（无新增能力）

### Modified Capabilities

- `abp-typed-device-cache`: 新增 `ConnectionRegistryCacheItem` 类型，拆分 `ClientRegistryCacheItem` 的双重注册表职责；消除 `DeviceStatusAppService` 中的直接缓存访问，全部通过 `IDeviceStatusService` 委托。
- `abp-blazor-server-hosting`: 将 `Models/` 目录重构为 `Cache/`、`Dtos/`、`Messages/` 子目录，更新所有命名空间和引用。

## Impact

### Code Change Map

| File Path | Change Type | Change Reason | Impact Scope |
|-----------|-------------|---------------|--------------|
| `Core/Models/Cache/` | CREATE (dir) | CacheItem 子目录 | 目录结构规范化 |
| `Core/Models/Dtos/` | CREATE (dir) | DTO 子目录 | 目录结构规范化 |
| `Core/Models/Messages/` | CREATE (dir) | Message 子目录 | 目录结构规范化 |
| `Core/Models/Cache/DeviceStatusCacheItem.cs` | MOVE | 从 Models/ 迁移至 Cache/ | 命名空间变更 |
| `Core/Models/Cache/ClientRegistryCacheItem.cs` | MOVE | 从 Models/ 迁移至 Cache/ | 命名空间变更 |
| `Core/Models/Cache/ClientConnectionCacheItem.cs` | MOVE | 从 Models/ 迁移至 Cache/ | 命名空间变更 |
| `Core/Models/Cache/ConnectionRegistryCacheItem.cs` | NEW | 拆分连接注册表语义 | 缓存类型新增 |
| `Core/Models/DeviceStatusCacheItem.cs` | DELETE | 已迁移至 Cache/ | 文件移动 |
| `Core/Models/ClientRegistryCacheItem.cs` | DELETE | 已迁移至 Cache/ | 文件移动 |
| `Core/Models/ClientConnectionCacheItem.cs` | DELETE | 已迁移至 Cache/ | 文件移动 |
| `Core/Models/Messages/DeviceStatusMessage.cs` | MOVE | 从 Models/ 迁移至 Messages/ | 命名空间变更 |
| `Core/Models/Dtos/*.cs` (~15 files) | MOVE | DTO 文件迁移至 Dtos/ | 命名空间变更 |
| `Core/Services/DeviceStatusService.cs` | MODIFY | 引用 ConnectionRegistryCacheItem；更新命名空间 | 缓存层 |
| `Core/Services/DeviceStatusAppService.cs` | MODIFY | 移除 IDistributedCache 注入，改用 IDeviceStatusService 委托；更新命名空间 | 服务层 |
| `Core/Hubs/DeviceStatusHub.cs` | MODIFY | 更新 Models 命名空间引用 | Hub 层 |
| `Core/UrbanManagementCoreModule.cs` | MODIFY | 添加 ConnectionRegistryCacheItem 过期策略配置 | 模块配置 |
| `App/Pages/DeviceStatus.razor` | MODIFY | 更新 Models 命名空间引用 | UI 层 |
| `App/Pages/ClientList.razor` | MODIFY | 更新 Models 命名空间引用 | UI 层 |
| `App/Pages/ClientDetail.razor` | MODIFY | 更新 Models 命名空间引用 | UI 层 |
| `App/Pages/_Imports.razor` | MODIFY | 更新 Models 命名空间引用 | UI 层 |
