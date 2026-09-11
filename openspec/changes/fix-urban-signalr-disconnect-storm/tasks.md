## 1. SignalR options

- [ ] 1.1 Extend `SignalROptions` with `KeepAliveIntervalSeconds` (default 15) and `ClientTimeoutIntervalSeconds` (default 60); document ClientTimeout must be greater than KeepAlive
- [ ] 1.2 Apply intervals in `UrbanManagementAppModule` `AddSignalR` and Blazor `AddHubOptions`; add defaults to `appsettings.json` under `SignalR`

## 2. Redis as primary for connection / device current state

- [ ] 2.1 Change `UpsertClientConnectedAsync` / `UpsertClientDisconnectedAsync` to write Redis only (set/clear connection cache + registry); **remove** EF `ClientOnlineStatus` insert/update from these paths
- [ ] 2.2 Change `HandleStatusUploadAsync` device-detail + LastSeen paths to Redis only; **remove** EF upserts to `ClientDeviceOnlineStatus` / `ClientOnlineStatus.LastSeenAt` on the hot path
- [ ] 2.3 Change connection and device query APIs used by management UI (`GetClientConnections*` / `GetClientDevices*` / project badge aggregation) to read **Redis only**; missing keys ⇒ offline/unregistered; **no SQLite fallback** for live badges
- [ ] 2.4 Apply TTL on connection/device keys (at least ~2× ClientTimeout); refresh TTL on connect and qualifying `UploadStatus`
- [ ] 2.5 Hub `OnDisconnectedAsync`: Redis offline update + best-effort `ClientConnectionUpdate`; no EF / no abort-CT SaveChanges path

## 3. Remove Web DeviceStatus SignalR (no polling)

- [ ] 3.1 Remove `HubConnection` / `InitializeSignalRAsync` / `SubscribeClientConnectionAsync` / reconnect handlers from `ProjectManagement.razor`
- [ ] 3.2 Remove `StartFallbackPolling` and any timer-based `GetClientListAsync` refresh; dispose related CTS
- [ ] 3.3 Ensure badges load on page init and user-driven reloads; add「刷新」if no clear manual reload path

## 4. Redis infrastructure (Windows tporadowski/redis)

- [ ] 4.1 Add `Volo.Abp.Caching.StackExchangeRedis` (ABP 10.0.1); `DependsOn` `AbpCachingStackExchangeRedisModule`
- [ ] 4.2 Add `Redis:Configuration` default `127.0.0.1:6379`; keep `AbpDistributedCacheOptions.KeyPrefix = "UM:"`
- [ ] 4.3 Ops checklist: tporadowski/redis on Windows, port **6379**, `maxmemory 100mb` + `allkeys-lru`; **no** SignalR Redis backplane
- [ ] 4.4 Redis down ⇒ observable failure; **no** silent in-memory fallback and **no** silent EF fallback for live status

## 5. Verify

- [ ] 5.1 Mass disconnect / status upload: no SQLite writes to `ClientOnlineStatuses` / device-online tables on Hub path; no `TaskCanceledException` SaveChanges storm from disconnect persistence
- [ ] 5.2 KeepAlive/ClientTimeout binding applied
- [ ] 5.3 Project Management: no `/hubs/devicestatus`; no 30s polling; manual refresh shows Redis-backed badges
- [ ] 5.4 Redis at 6379 with maxmemory 100mb: connect/upload populates `UM:` keys; flush/restart Redis ⇒ badges offline until clients reconnect
