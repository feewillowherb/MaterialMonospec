# Design: Enhance Device Health Polling, Gate IO Status, and Admin Detail View

## Structured `AdditionalData` JSON Schema

```json
{
  "onlineCount": 1,
  "totalCount": 2,
  "items": [
    { "name": "北门抓拍机", "endpoint": "192.168.1.101:8000", "isOnline": true, "detail": null },
    { "name": "南门抓拍机", "endpoint": "192.168.1.102:8000", "isOnline": false, "detail": "设备离线" }
  ]
}
```

## Aggregation Rules (`DeviceHealthSnapshotFormatter.Summarize`)

- `items.Count == 0` → `Offline`
- `onlineCount == items.Count` → `Online`
- `0 < onlineCount < items.Count` → `Degraded`
- `onlineCount == 0` → `Offline`

## Periodic Probe Cadence

- `DeviceHealthProbeService` lives in `MaterialClient.Common/Services/` (shared for Urban and future hosts).
- `ClientHeartbeatBackgroundWorker` invokes `ProbeAllAsync` on first tick and thereafter at `SignalR:DeviceHealthProbeIntervalSeconds` (default `60` seconds, clamped `[15, 600]`), before reading `DeviceStatusEventHandler.GetLatestDeviceSnapshots()`.
- Camera probes run off the caller thread (`Task.Run`) and never throw out of the loop; Gate IO is only reported when at least one LPR config enables `EnableGateIo` (avoiding false alarms at sites without gate IO).

## Admin UI Enhancement (`ProjectManagement.razor`)

- Device detail modal parses `device.AdditionalData` via static `DeviceHealthDetailParser.TryParse`.
- Displays per-endpoint status rows (`Name`, `Endpoint`, online/offline dot, optional `Detail`) below the device card summary when structured items exist.
- Adds a modal filter bar (`全部设备` vs `仅看异常`) filtering to devices where `Status != "Online"` or any child endpoint is offline.
