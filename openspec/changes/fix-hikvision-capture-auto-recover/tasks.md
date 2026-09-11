## 1. Diagnosis logging and timeout config

- [ ] 1.1 Add `StreamCaptureDecoderTimeoutMs` to `SystemSettings` (default 5000); wire into `CaptureJpegFromStream` `WaitForPlaying`
- [ ] 1.2 On `WaitForPlaying` timeout: if port unassigned / not initialized, log `no_syshead` and avoid reporting PlayM4 error 32 as root cause; otherwise log real PlayM4 error
- [ ] 1.3 Confirm Mainstream batch path always attempts `CaptureJpeg` fallback after decoder timeout (fix if any early-return skipped fallback)

## 2. SDK soft reset

- [ ] 2.1 Add named `record` for soft-reset outcome (e.g. `SdkSoftResetResult`) — no tuples
- [ ] 2.2 Implement thread-safe soft reset on `HikvisionService`: logout all cached sessions → clear cache → `NET_DVR_Cleanup` → clear `_initialized` → short delay → `NET_DVR_Init`; include cooldown (30s) and mutual exclusion
- [ ] 2.3 Verify `HikvisionLprService` shares the same init flag / Cleanup contract; align so LPR does not assume init after soft reset without re-EnsureInitialized
- [ ] 2.4 In `CaptureJpegFromStreamBatchAsync` (and shared batch entry used by weighing): on total failure, soft-reset (if cooldown allows) and retry the batch once; log recovery or cooldown skip

## 3. Weighing capture integration

- [ ] 3.1 Ensure `WeighingCaptureService.CaptureAllCamerasAsync` benefits from batch-level reset+retry (prefer encapsulating in Hikvision batch API so TestCapture shares behavior)
- [ ] 3.2 Keep empty-list + warning behavior when both attempts fail; do not throw into weighing state machine

## 4. Tests and verify

- [ ] 4.1 Unit/integration tests: timeout diagnostics (no_syshead), fallback still invoked on timeout, soft-reset cooldown skips second Cleanup, batch retry after reset (mock/fake where device unavailable)
- [ ] 4.2 Build MaterialClient; smoke TestCapture or attended weighing capture path if hardware available
- [ ] 4.3 Mark tasks complete; note field verify: consecutive no-photo then recover without process restart
