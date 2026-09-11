## 1. SignalR options

- [ ] 1.1 Extend `SignalROptions` with `KeepAliveIntervalSeconds` (default 15) and `ClientTimeoutIntervalSeconds` (default 60); document ClientTimeout must be greater than KeepAlive
- [ ] 1.2 Apply intervals in `UrbanManagementAppModule` `AddSignalR` and Blazor `AddHubOptions`; add defaults to `appsettings.json` under `SignalR`

## 2. Disconnect persistence resilience

- [ ] 2.1 Inject `IServiceScopeFactory` into `DeviceStatusHub`; on disconnect, create a new scope and resolve `IDeviceStatusService` for offline upsert (do not use connection-abort CT)
- [ ] 2.2 Run disconnect upsert with an independent short timeout CTS (or `CancellationToken.None` if service methods lack CT params today); ensure EF work is not canceled solely by hub abort
- [ ] 2.3 Downgrade expected cancel / timeout on disconnect persist to Warning (or Debug); keep Error for unexpected failures; keep broadcasting `ClientConnectionUpdate` best-effort for non-Web subscribers

## 3. Remove Web DeviceStatus SignalR (no polling)

- [ ] 3.1 Remove `HubConnection` / `InitializeSignalRAsync` / `SubscribeClientConnectionAsync` / reconnect handlers from `ProjectManagement.razor`
- [ ] 3.2 Remove `StartFallbackPolling` and any timer-based `GetClientListAsync` refresh; dispose related CTS
- [ ] 3.3 Ensure client badges still load on page init and on user-driven reloads; add an explicit「刷新」control if the page has no clear manual reload path (no auto interval)

## 4. Redis distributed cache (Windows tporadowski/redis)

- [ ] 4.1 Add `Volo.Abp.Caching.StackExchangeRedis` (ABP 10.0.1) to Directory.Packages.props and the appropriate project(s); `DependsOn` `AbpCachingStackExchangeRedisModule` (replace pure in-memory `IDistributedCache` backend)
- [ ] 4.2 Add `Redis:Configuration` default `127.0.0.1:6379` to `appsettings.json`; keep `AbpDistributedCacheOptions.KeyPrefix = "UM:"` and existing CacheItem TTLs
- [ ] 4.3 Document / checklist for ops: install [tporadowski/redis](https://github.com/tporadowski/redis) on Windows, default port **6379**, `maxmemory 100mb` + `maxmemory-policy allkeys-lru` in redis config; do **not** add SignalR Redis backplane
- [ ] 4.4 Verify app writes/reads device-status / connection cache via Redis (`UM:` keys); Redis down is logged as failure (no silent memory fallback)

## 5. Verify

- [ ] 5.1 Disconnect upsert under abort CT: no Error storm of `TaskCanceledException` on `SaveChanges`
- [ ] 5.2 Confirm KeepAlive/ClientTimeout binding applied
- [ ] 5.3 Browser on Project Management: no `/hubs/devicestatus` negotiation; no 30s polling; desktop hub still works; manual refresh updates badges
- [ ] 5.4 With Redis running at 6379 and maxmemory 100mb: status upload / connect path populates Redis; after app recycle, cache keys still present until TTL/eviction