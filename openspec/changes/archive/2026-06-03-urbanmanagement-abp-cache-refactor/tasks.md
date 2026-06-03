## 1. Package & Module Dependencies

- [x] 1.1 Add `Volo.Abp.Caching` package reference to `UrbanManagement.Core.csproj`
- [x] 1.2 Add `typeof(AbpCachingModule)` to `UrbanManagementCoreModule` `[DependsOn]` attribute
- [x] 1.3 Add `Configure<AbpDistributedCacheOptions>` block in `UrbanManagementCoreModule.ConfigureServices` with per-type TTL and key prefix `"UM:"`

## 2. CacheItem Class Definitions

- [x] 2.1 Create `Models/DeviceStatusCacheItem.cs` — `List<DeviceStatusMessage> Messages`, `[CacheName("DeviceStatus")]`
- [x] 2.2 Create `Models/ClientRegistryCacheItem.cs` — `HashSet<string> ProIds`, `[CacheName("ClientRegistry")]`
- [x] 2.3 Create `Models/ClientConnectionCacheItem.cs` — ProId, ProName, IsConnected, ConnectedAt, DisconnectedAt, `[CacheName("ClientConnection")]`
- [x] 2.4 Create `Models/ConnectionRegistryCacheItem.cs` — `HashSet<string> ProIds`, `[CacheName("ConnectionRegistry")]`

## 3. DeviceStatusService Refactoring

- [x] 3.1 Replace `IDistributedCache _distributedCache` field with 4 typed `IDistributedCache<T>` fields using `[AutoConstructor]`
- [x] 3.2 Rewrite `CacheMessageAsync` — use `GetAsync`/`SetAsync` on `IDistributedCache<DeviceStatusCacheItem>`, keep FIFO logic (max 100)
- [x] 3.3 Rewrite `GetCachedMessagesAsync` — use `GetAsync` on typed cache, return `Messages` list or empty
- [x] 3.4 Rewrite `ClearCachedMessagesAsync` — use `RemoveAsync` on typed cache
- [x] 3.5 Rewrite `GetAllCachedClientIdsAsync` and `UpdateClientRegistryAsync` — use `IDistributedCache<ClientRegistryCacheItem>`
- [x] 3.6 Rewrite `CacheClientConnectedAsync` — use `SetAsync` on `IDistributedCache<ClientConnectionCacheItem>`
- [x] 3.7 Rewrite `CacheClientDisconnectedAsync` — use `GetAsync`/`SetAsync` on `IDistributedCache<ClientConnectionCacheItem>` (remove anonymous object and manual JSON parse)
- [x] 3.8 Rewrite `GetClientConnectionAsync` — use `GetAsync` on `IDistributedCache<ClientConnectionCacheItem>` (remove `JsonDocument.Parse` manual parsing)
- [x] 3.9 Rewrite `GetAllConnectionRegistryIdsAsync` and `UpdateConnectionRegistryAsync` — use `IDistributedCache<ConnectionRegistryCacheItem>`

## 4. DeviceStatusAppService Refactoring

- [x] 4.1 Remove `IDistributedCache _distributedCache` field from `DeviceStatusAppService`
- [x] 4.2 Inject `IDistributedCache<DeviceStatusCacheItem>` and rewrite `GetAllDeviceStatusFromCacheAsync` to use typed cache reads
- [x] 4.3 Rewrite `GetClientDevicesAsync` to use typed cache instead of raw `GetStringAsync`

## 5. DeviceStatusHub Cleanup

- [x] 5.1 Remove `IDistributedCache` parameter from `DeviceStatusHub` constructor

## 6. Cleanup

- [x] 6.1 Delete `Tools/DateTimeJsonConverter.cs` (contains `DateTimeJsonConverter` and `NullableDateTimeJsonConverter`)
