## 1. Config helpers and event shape

- [x] 1.1 Add `LicensePlateRecognitionConfig.FindAllByIp` (or equivalent type-owned static) returning distinct valid rows for a normalized IP
- [x] 1.2 Add optional `DeviceIp` on `LicensePlateRecognizedEventData` without breaking existing publishers/consumers

## 2. Publish-time fan-out

- [x] 2.1 Extract or add a shared publish helper that takes one recognition payload + IP, loads settings rows via `FindAllByIp`, and publishes one event per row (fallback to SDK map single config when no settings match)
- [x] 2.2 Wire helper into `VzvisionLprService` plate callback (replace single-config publish)
- [x] 2.3 Wire helper into `HikvisionLprService` plate callback (same semantics)
- [x] 2.4 Confirm test-injection / MinimalWebHost LPR publish paths remain single-event (no IP fan-out)

## 3. Gate and active-trigger dedupe

- [x] 3.1 Update `GateIoControlService` for shared-IP fan-out: ~2s same-plate dedupe; prefer Scale + `EnableGateIo` when multiple rows enable gate
- [x] 3.2 Update `WeighingCaptureService` (or equivalent) so WeightStabilized LPR trigger calls `TriggerCaptureAsync` at most once per distinct IP

## 4. Verification

- [x] 4.1 Add/adjust unit tests for `FindAllByIp`, fan-out publish count (scale+product same IP → 2 events; single row → 1; duplicate Name → 1)
- [x] 4.2 Add/adjust tests for gate dedupe preference and active-trigger IP dedupe
- [x] 4.3 Build MaterialClient (`dotnet build ... -o .build-verify` if file locks) and mark tasks complete
