## 1. API contract

- [x] 1.1 Add `SoundDeviceStatusRequestDto` (type/app/sn) for POST body
- [x] 1.2 Change `ISoundDeviceApi.GetDeviceStatusAsync` to `[Post("/api/devices/getDeviceBySN")]` with `[Body]` request
- [x] 1.3 Extend `SoundDeviceStatusDto` with optional `msg` for diagnostics

## 2. Service

- [x] 2.1 Update `SoundDeviceService.IsOnlineAsync` BaseURL to `http://{LocalIP}:17808` and call POST with request DTO
- [x] 2.2 Treat missing/non-online status (including device-not-found `msg`) as offline; keep play path on `{SoundIP}:8888`

## 3. Verify

- [x] 3.1 Build `MaterialClient.Common` (or solution via `.build-verify`) to confirm compile
- [x] 3.2 Smoke-check POST against live mgrserver if reachable
