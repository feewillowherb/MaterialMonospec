## 1. Offline Redis retention TTL

- [x] 1.1 Add `SignalROptions.OfflineRetentionDays` (default 7) and `appsettings.json` `SignalR:OfflineRetentionDays`
- [x] 1.2 `UpsertClientDisconnectedAsync`: set `IsConnected=false` with offline TTL (do not delete key); use offline TTL for connection registry updates
- [x] 1.3 Keep online connect / `UploadStatus` refresh on short live TTL (≥ 2× ClientTimeout)

## 2. Query: Redis then EF offline fallback

- [x] 2.1 Extend connection list query to merge Redis hits with EF `ClientOnlineStatus` rows missing from Redis
- [x] 2.2 Map EF fallback instances as **offline** for aggregation (never promote Redis-miss EF `IsConnected=true` to 在线)
- [x] 2.3 Confirm project badge aggregation still yields 在线 / 离线 / 未注册 per merged set

## 3. Daily Redis → EF snapshot worker

- [x] 3.1 Add configurable BackgroundWorker (~24h) that reads Redis connection registry/payloads and upserts `ClientOnlineStatus` under its own UoW
- [x] 3.2 Snapshot device current-state from Redis into `ClientDeviceOnlineStatus` (or equivalent) in the same worker
- [x] 3.3 Ensure Hub connect/disconnect/`UploadStatus` paths still perform **zero** EF upserts; worker failures are logged only

## 4. Verify

- [ ] 4.1 Disconnect → badge 离线 for > live TTL (e.g. beyond ~2 minutes) while within 7-day retention
- [ ] 4.2 After Redis key expiry/flush with EF rows present → badge 离线 (not 未注册); never-seen project → 未注册
- [ ] 4.3 Trigger or wait for snapshot → EF rows match Redis; Hub storm path still has no EF on disconnect
