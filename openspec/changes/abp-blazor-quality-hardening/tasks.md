## 1. Models 目录重组

- [ ] 1.1 在 `UrbanManagement.Core/Models/` 下创建 `Cache/`、`Dtos/`、`Messages/` 三个子目录
- [ ] 1.2 将 `DeviceStatusCacheItem.cs`、`ClientRegistryCacheItem.cs`、`ClientConnectionCacheItem.cs` 从 `Models/` 根目录移动到 `Models/Cache/`，保持 `UrbanManagement.Core.Models` 命名空间不变
- [ ] 1.3 将所有 DTO 文件（ClientConnectionDto、ClientDeviceSummaryDto、DeviceStatusQueryDto、DeviceStatusListRequestDto、ClientListRequestDto、GovProjectDto、GovProjectCreateDto、GovProjectUpdateDto、GovProjectListRequestDto、GovLogDto、GovSyncDataDto、GovSyncDataQueryDtos、LegacyGovSyncDtos、LegacyGovSyncResult、PagedResult、SetSyncStatusDto、UrbanAttachmentUploadDtos、UrbanWeighingRecordDtos、UrbanWeighingRecordOutputDto）从 `Models/` 根目录移动到 `Models/Dtos/`，保持命名空间不变
- [ ] 1.4 将 `DeviceStatusMessage.cs` 从 `Models/` 根目录移动到 `Models/Messages/`，保持命名空间不变
- [ ] 1.5 删除 `Models/` 根目录下的所有已迁移文件，确认根目录无残留模型文件
- [ ] 1.6 验证项目编译通过（命名空间未变，仅物理路径变更）

## 2. ConnectionRegistryCacheItem 恢复

- [ ] 2.1 在 `Models/Cache/` 目录下创建 `ConnectionRegistryCacheItem.cs`：`HashSet<string> ProIds` 属性，`[CacheName("ConnectionRegistry")]` 属性，`UrbanManagement.Core.Models` 命名空间
- [ ] 2.2 在 `UrbanManagementCoreModule.ConfigureServices` 的 `Configure<AbpDistributedCacheOptions>` 中添加 `ConnectionRegistryCacheItem` 过期策略配置（`AbsoluteExpirationRelativeToNow = 25h`）
- [ ] 2.3 更新 `DeviceStatusService`：将 `_clientRegistryCache` 字段拆分为 `_clientRegistryCache`（IDistributedCache\<ClientRegistryCacheItem\>）和 `_connectionRegistryCache`（IDistributedCache\<ConnectionRegistryCacheItem\>）
- [ ] 2.4 更新 `DeviceStatusService.GetAllConnectionRegistryIdsAsync`：改用 `_connectionRegistryCache.GetAsync("__connection_registry__")`
- [ ] 2.5 更新 `DeviceStatusService.UpdateConnectionRegistryAsync`：改用 `_connectionRegistryCache.SetAsync("__connection_registry__", ...)`，创建 `ConnectionRegistryCacheItem` 实例
- [ ] 2.6 验证项目编译通过

## 3. AppService 缓存边界治理

- [ ] 3.1 在 `IDeviceStatusService` 接口中新增 `Task<List<DeviceStatusMessage>> GetDeviceMessagesAsync(string proId)` 方法
- [ ] 3.2 在 `DeviceStatusService` 中实现 `GetDeviceMessagesAsync`：调用 `_deviceStatusCache.GetAsync(proId)` 并返回 `Messages` 列表
- [ ] 3.3 从 `DeviceStatusAppService` 中移除 `IDistributedCache<DeviceStatusCacheItem>` 字段注入
- [ ] 3.4 重写 `DeviceStatusAppService.GetClientDevicesAsync`：改用 `_deviceStatusService.GetDeviceMessagesAsync(proId)` 获取数据
- [ ] 3.5 重写 `DeviceStatusAppService.GetAllDeviceStatusFromCacheAsync`：改用 `_deviceStatusService.GetAllCachedClientIdsAsync()` + `_deviceStatusService.GetCachedMessagesAsync(key)` 获取数据，移除直接缓存访问
- [ ] 3.6 验证项目编译通过
