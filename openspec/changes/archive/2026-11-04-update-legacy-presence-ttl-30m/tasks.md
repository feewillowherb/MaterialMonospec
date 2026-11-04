## 1. Configuration

- [x] 1.1 Add `LegacyLiveTtlMinutes` to `SignalROptions` (default 30; clamp with `Math.Max(1, …)`)
- [x] 1.2 Optionally document the key under Hosting `appsettings.json` `SignalR` section (default 30; no secret)

## 2. DeviceStatusService live TTL split

- [x] 2.1 Add helper to detect `legacy:` ClientId prefix (OrdinalIgnoreCase) and resolve live TTL (Legacy minutes vs existing `GetLiveTtl()`)
- [x] 2.2 Apply Legacy live TTL on live `SetConnectionCacheAsync` / Touch / UpsertConnected paths for `legacy:` ids; leave non-legacy and offline-retention paths unchanged
- [x] 2.3 Ensure registry update behavior stays compatible (do not shorten offline registry retention)

## 3. Tests

- [x] 3.1 Unit test: Touch/upsert with `ClientId=legacy:…` uses ~30 minute AbsoluteExpiration (or inspect options passed to cache)
- [x] 3.2 Unit test: non-`legacy:` ClientId still uses SignalR-derived short live TTL
- [x] 3.3 Keep existing Receive/Legacy presence wiring (`SubmitMachineCode` / `BuildLegacyPresenceClientId`); add or extend test that Legacy receive still Touches

## 4. Verify

- [ ] 4.1 After apply: successful Legacy `/Api/Post` → Redis `ClientConnection` for `legacy:{AccessCode}` has TTL ≈ 1800s and client-list shows `isConnected=true`
- [ ] 4.2 Confirm a non-legacy SignalR presence key (if available) still uses short TTL
