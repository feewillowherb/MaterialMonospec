# Investigation: Urban client shows offline in UM after boot (~7 min)

## Hand-off Brief

1. **What happened.** Urban desktop stays open with no client errors, but UM management shows the project/client offline after a short post-boot window.
2. **Where the case stands.** Root mechanism Confirmed in code: Redis live online TTL (~2× ClientTimeout ≈ 2 min) only refreshes on `UploadStatus`; client uploads only on device status *changes*, not on a heartbeat. Wall-clock “~7 minutes” from boot is still Unconfirmed (may be estimate or last-status timing).
3. **What's needed next.** Measure last `UploadStatus` / Redis TTL / UM badge flip timestamps on one repro; then decide whether to add periodic status republish or SignalR-presence-based online.

## Case Info

| Field            | Value |
| ---------------- | ----- |
| Ticket           | N/A |
| Date opened      | 2026-09-16 |
| Status           | Active |
| System           | MaterialClient.Urban + UrbanManagement DeviceStatus SignalR/Redis |
| Evidence sources | Source code, OpenSpec changes (`fix-urban-signalr-disconnect-storm`, `update-urban-offline-retention`), user observation |

## Problem Statement

User report (hypothesis): after Urban client power-on, about seven minutes later UM shows the client offline; logs have no errors; the client UI remains running normally.

## Evidence Inventory

| Source | Status | Notes |
| ------ | ------ | ----- |
| User observation | Partial | Symptom described; no log files / Redis TTL dump / exact timing attached |
| UM `DeviceStatusService` live TTL | Available | `GetLiveTtl()` = max(60, ClientTimeout)×2 → default 120s |
| UM appsettings SignalR | Available | KeepAlive 15s, ClientTimeout 60s, OfflineRetentionDays 7 |
| Client `SharedDeviceStatusTracker` | Available | Polls hardware; publishes only on online/offline *change* |
| Client `DeviceStatusSignalRClient` | Available | Keepalives implicit; no Hub heartbeat; reconnect logs would appear on disconnect |
| Runtime logs / Redis MONITOR | Missing | Would confirm exact flip time vs last UploadStatus |

## Investigation Backlog

| # | Path to Explore | Priority | Status | Notes |
| - | --------------- | -------- | ------ | ----- |
| 1 | Live Redis TTL + UploadStatus refresh path | High | Done | Confirmed short TTL, refresh only on UploadStatus |
| 2 | Client publish cadence (change-only vs heartbeat) | High | Done | Change-only; matches “no dedicated heartbeat” spec |
| 3 | Why ~7 minutes specifically | Medium | Open | Default live TTL is ~2 min; OfflineRetentionDays=7 days |
| 4 | Field timing: last UploadStatus → badge offline | High | Open | Needs logs/Redis TTL |
| 5 | Whether SignalR connection still Connected when badge offline | Medium | Open | Explains silent client logs if true |

## Timeline of Events

| Time | Event | Source | Confidence |
| ---- | ----- | ------ | ---------- |
| T0 boot | Client starts; SignalR connects; devices poll; status changes → UploadStatus → Redis IsConnected=true | Code path | Deduced |
| T0+ε | Devices stabilize (no further Online/Offline flips) → no more UploadStatus | `SharedDeviceStatusTracker.UpdateDeviceOnline` | Confirmed (code) |
| T_last + ~2 min | Redis live key AbsoluteExpiration expires → list Redis miss → EF offline fallback | `GetLiveTtl` + `FromEntityAsOfflineFallback` | Deduced |
| User “~7 min” | Observed badge offline from boot | User | Hypothesized timing |

## Confirmed Findings

### Finding 1: UM “online” is Redis live entry with short AbsoluteExpiration TTL

**Evidence:** `repos/UrbanManagement/.../DeviceStatusService.cs` `GetLiveTtl` / `CreateLiveCacheOptions`; `appsettings.json` `ClientTimeoutIntervalSeconds: 60`

**Detail:** Live TTL = `max(60, ClientTimeoutIntervalSeconds) * 2` → **120 seconds** with defaults. Offline retention is separately **7 days** (`OfflineRetentionDays`), not minutes.

### Finding 2: Live TTL is refreshed only by connect upsert / UploadStatus — not by SignalR keepalives

**Evidence:** `HandleStatusUploadAsync` → `TryRefreshLastSeenInCacheAsync` / `UpsertDeviceOnlineDetailInCacheAsync`; OpenSpec `device-online-status-persistence` “LastSeenAt refresh without dedicated heartbeat”

**Detail:** Transport keepalives keep the Hub socket alive but do not rewrite the Redis connection key. Silent socket ≠ live badge.

### Finding 3: Urban client only UploadStatus on device status transitions

**Evidence:** `SharedDeviceStatusTracker.UpdateDeviceOnline` early-returns when unchanged; `DeviceStatusEventHandler` forwards change events; republish only on SignalR restore / monitor start

**Detail:** After boot settle, a quiet hardware set produces no UploadStatus → Redis TTL not refreshed → badge goes offline while the process can still look healthy.

### Finding 4: Redis miss forces offline in UI even if EF had IsConnected=true

**Evidence:** `ClientConnectionDto.FromEntityAsOfflineFallback` sets `IsConnected = false`; `GetLiveClientConnectionsAsync` merges Redis then EF fallback

**Detail:** Matches “shows offline” without requiring an explicit disconnect event.

### Finding 5: Explicit disconnect would log on server; TTL expiry need not

**Evidence:** `DeviceStatusHub.OnDisconnectedAsync` logs disconnect; AbsoluteExpiration drop leaves no Hub disconnect if socket still open

**Detail:** Consistent with “no errors in logs” if the socket never closed.

## Deduced Conclusions

### Deduction 1: False offline is an expected consequence of short live TTL + change-only uploads

**Based on:** Findings 1–4

**Reasoning:** Online badge requires a Redis key that expires ~2 minutes after the last UploadStatus/connect write. Client does not heart beat. Stable devices stop uploading. Badge flips to offline while the Urban process remains open.

**Conclusion:** The reported class of symptom is **real and explained by design**, not a mysterious crash. Exact “seven minutes from boot” is not the coded live TTL; it is either approximate, boot+last-change lag, or a different production timeout.

## Hypothesized Paths

### Hypothesis 1: Redis live TTL expiry after last UploadStatus (no disconnect)

**Status:** Confirmed (mechanism) / Open (field timing = 7 min)

**Theory:** Last device status upload shortly after boot; ~2 min later Redis live key gone; UM shows offline; SignalR may still be Connected.

**Supporting indicators:** Matches silent client logs; matches OpenSpec “no dedicated heartbeat”; matches live TTL formula.

**Would confirm:** Client log last `UploadStatus` / server Debug UploadStatus timestamp; Redis TTL on `UM:` connection key; Hub connection still present when badge offline.

**Would refute:** Server `Client disconnected` at flip time; Redis key still present with IsConnected=true when UI shows offline.

**Resolution:** Mechanism Confirmed in code; wall-clock 7 min not yet measured.

### Hypothesis 2: User conflated OfflineRetentionDays=7 with minutes

**Status:** Open

**Theory:** “七” comes from retention config or rough estimate rather than measured interval.

**Would confirm:** Measured flip ≈ 2 minutes after last status upload, not 7 after boot.

**Would refute:** Repeated measured boot→offline ≈ 7±1 minutes with continuing UploadStatus until then.

### Hypothesis 3: Actual SignalR disconnect / ClientTimeout storm

**Status:** Open (less likely given “no log errors”)

**Theory:** Server closes idle Hub; disconnect path marks offline.

**Would confirm:** UM `DeviceStatusHub: Client disconnected` near flip; client `Connection closed` / reconnect logs.

**Would refute:** No disconnect logs; Redis key simply missing while Hub still Connected.

## Missing Evidence

| Gap | Impact | How to Obtain |
| --- | ------ | ------------- |
| Exact boot → offline delta | Settles 2 min vs 7 min narrative | Stopwatch + UM UI; or screenshot timestamps |
| Last UploadStatus time | Ties flip to TTL | Enable Debug for Hub UploadStatus; client Debug for sent status |
| Redis key TTL at flip | Proves AbsoluteExpiration path | `TTL` on connection cache key when badge flips |
| Hub still Connected? | Distinguishes H1 vs H3 | Server connection map / client `IsConnected` at flip |

## Source Code Trace

| Element | Detail |
| ------- | ------ |
| Error origin | Not an exception — Redis live key expiry + offline EF fallback |
| Trigger | No UploadStatus for ≥ live TTL while management queries connections |
| Condition | Device statuses stable after boot; SignalR may remain up |
| Related files | `UrbanManagement.../DeviceStatusService.cs`, `SignalROptions.cs`, `ClientConnectionDto.cs`, `MaterialClient.../SharedDeviceStatusTracker.cs`, `DeviceStatusEventHandler.cs`, `DeviceStatusSignalRClient.cs` |

## Conclusion

**Confidence:** High (mechanism) / Medium (exact 7-minute wall clock)

UM online badges are Redis-backed with a **~2 minute** live TTL refreshed only by `UploadStatus`. The Urban client does **not** send a periodic presence heartbeat—only device status changes. After hardware settles post-boot, uploads stop, the live key expires, and the list falls back to an **forced-offline** EF shell. That matches “client still open, no errors, UM shows offline.” The literal “开机七分钟” is not what the default TTL encodes (2 min after last upload; offline retention is 7 **days**); measure one repro to lock the timing.

## Recommended Next Steps

### Fix direction

1. **Presence refresh (product):** periodic `UploadStatus` / republish (e.g. every ≤ liveTTL/2) or Hub ping that refreshes Redis TTL while Connected.
2. **Or derive online from Hub connection map** when Redis TTL is only for ghost protection—design tradeoff vs multi-instance Redis truth.
3. Do not treat OfflineRetentionDays=7 as the online timeout.

### Diagnostic

1. On one machine: note boot time, time of last client status send, time UM badge flips.
2. At flip: Redis `GET`/`TTL` for connection key; check UM for disconnect logs; check client for `Connection closed`.

## Reproduction Plan

1. Start Urban client against UM+Redis with default SignalR timeouts.
2. Ensure devices stay Online without flapping.
3. Watch UM project/client online badge; expect offline ~2 minutes after last UploadStatus (may be a few minutes after boot if late device settle).
4. Confirm client window still open and no SignalR error logs.

## Side Findings

- `DeviceStatusEventHandler.ShouldThrottle` logs throttle but still sends (throttle does not `return`) — unrelated to silent offline, but throttle is ineffective.
- OpenSpec intentionally omitted a dedicated heartbeat; this false-offline class is a known risk called out in storm-fix design (“TTL/LRU 导致误显示离线”).

## Follow-up: 2026-09-16

Awaiting user direction: field timing capture vs proceed to OpenSpec fix (periodic republish / presence).
