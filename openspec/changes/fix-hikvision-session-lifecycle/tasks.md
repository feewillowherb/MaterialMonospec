## 1. Session store foundation

- [x] 1.1 Bind P/Invoke `NET_DVR_RemoteControl` and constant `NET_DVR_CHECK_USER_STATUS = 20005` (locked decision; confirm `lpInBuffer` nullability vs Demo)
- [x] 1.2 Add named `record` probe/session result types (no tuples) under Hikvision services
- [x] 1.3 Implement shared login session store (Acquire / Release / Invalidate / InvalidateAll) keyed by device identity; wire P/Invoke Login/Logout only through the store
- [x] 1.4 Register store per `minimal-di` (only if I/O/lifecycle requires DI; prefer singleton shared with both services)

## 2. LPR long session + online probe

- [x] 2.1 Change `HikvisionLprService.IsOnline` to throttled `RemoteControl(CHECK_USER_STATUS)` on cached `userId`; remove Login→Logout success path
- [x] 2.2 On LPR `StartAsync` after successful `StartListen`, Acquire sessions for configured Hikvision LPR devices
- [x] 2.3 `TriggerCaptureAsync` uses Acquire/cached `userId` only; on session-style Shoot failure Invalidate + one Acquire retry
- [x] 2.4 `StopAsync` stops Listen and Releases LPR-held sessions via the store

## 3. Monitoring capture + soft-reset linkage

- [x] 3.1 Route `HikvisionService` login/logout through the same session store (same device key)
- [x] 3.2 In `TrySoftResetSdkAsync`, InvalidateAll before/after Cleanup as designed; clear LPR listen handle validity
- [x] 3.3 After soft-reset success, rebuild LPR `StartListen` and re-Acquire LPR device sessions (no SetupAlarmChan)

## 4. Observability

- [x] 4.1 After ContinuousShoot accepted, start timeout window; if no related plate/ITS callback, LogWarning
- [x] 4.2 Ensure soft-reset and listen rebuild paths log clear INF/WRN with handles and error codes

## 5. Verify

- [x] 5.1 Unit/integration tests for session store Acquire/Release/Invalidate and IsOnline no Login/Logout churn (mocks as existing patterns allow)
- [x] 5.2 `dotnet build` MaterialClient (use `.build-verify` if locks) — no references to SetupAlarmChan in this change's new startup path
- [ ] 5.3 Manual: Urban only — confirm fewer `:8000` RST on idle online checks; Shoot without callback produces Warning; soft-reset (if cameras configured) rebuilds Listen
