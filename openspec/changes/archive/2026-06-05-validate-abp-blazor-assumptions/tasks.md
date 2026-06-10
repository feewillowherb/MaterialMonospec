## 1. Move Blazor Server Registration to App Module

- [x] 1.1 Remove `Volo.Abp.AspNetCore.Components.Server` package reference from `UrbanManagement.Core/UrbanManagement.Core.csproj`
- [x] 1.2 Add `Volo.Abp.AspNetCore.Components.Server` package reference to `UrbanManagement.App/UrbanManagement.App.csproj` (if not already transitive)
- [x] 1.3 Remove `context.Services.AddServerSideBlazor()` call from `UrbanManagementCoreModule.ConfigureServices`
- [x] 1.4 Add `context.Services.AddServerSideBlazor()` call to `UrbanManagementAppModule.ConfigureServices`
- [x] 1.5 Verify no Core code references Blazor-specific types (`ComponentBase`, `LayoutComponentBase`, etc.)

## 2. Consolidate ConnectionRegistryCacheItem into ClientRegistryCacheItem

- [x] 2.1 In `DeviceStatusService.cs`, replace `IDistributedCache<ConnectionRegistryCacheItem>` field with a distinct cache key constant `"__connection_registry__"` using the existing `IDistributedCache<ClientRegistryCacheItem>` field
- [x] 2.2 Update `DeviceStatusService.GetAllConnectionRegistryIdsAsync` to use `IDistributedCache<ClientRegistryCacheItem>` with key `"__connection_registry__"`
- [x] 2.3 Update `DeviceStatusService.CacheClientConnectedAsync` to write connection registry via `IDistributedCache<ClientRegistryCacheItem>` with key `"__connection_registry__"`
- [x] 2.4 Update `DeviceStatusService.CacheClientDisconnectedAsync` to update connection registry via `IDistributedCache<ClientRegistryCacheItem>` with key `"__connection_registry__"`
- [x] 2.5 In `DeviceStatusAppService.cs`, replace `IDistributedCache<ConnectionRegistryCacheItem>` usage with `IDistributedCache<ClientRegistryCacheItem>` and key `"__connection_registry__"`
- [x] 2.6 Remove `ConnectionRegistryCacheItem` expiration configuration from `AbpDistributedCacheOptions` in `UrbanManagementCoreModule`
- [x] 2.7 Delete `UrbanManagement.Core/Models/ConnectionRegistryCacheItem.cs`

## 3. Remove Unused Cache Injections from DeviceStatus.razor

- [x] 3.1 Remove `@inject IDistributedCache<ClientRegistryCacheItem>` from `DeviceStatus.razor`
- [x] 3.2 Remove `@inject IDistributedCache<DeviceStatusCacheItem>` from `DeviceStatus.razor`
- [x] 3.3 Remove `@inject IDistributedCache<ClientConnectionCacheItem>` from `DeviceStatus.razor`
- [x] 3.4 Remove any unused `@using` directives related to removed cache types from `DeviceStatus.razor`

## 4. Add Iteration Cap Guard in DeviceStatusAppService

- [x] 4.1 Add `private const int MaxRegistryIteration = 500;` constant to `DeviceStatusAppService`
- [x] 4.2 In `GetListAsync`, after reading ProIds from registry, add guard: if count exceeds `MaxRegistryIteration`, log warning and truncate
- [x] 4.3 In `GetClientListAsync`, after reading ProIds from connection registry, add same guard

## 5. Build Validation

- [x] 5.1 Run `dotnet build` on UrbanManagement solution and verify zero errors
- [x] 5.2 Verify `UrbanManagement.Core.csproj` no longer references `Volo.Abp.AspNetCore.Components.Server`
- [x] 5.3 Verify `ConnectionRegistryCacheItem.cs` file is deleted
- [x] 5.4 Verify `DeviceStatus.razor` only injects `IDeviceStatusAppService` and `NavigationManager` (no cache injections)
