## 1. Stability algorithm

- [x] 1.1 Rewrite `WeighingStreamPipeline.CreateStabilityStream`: downsample by `StabilityCheckIntervalMs` (last of each buffer), then sliding window of `periods = max(1, floor(StabilityWindowMs / StabilityCheckIntervalMs))`
- [x] 1.2 Stable only when window length equals `periods`, every sample `> MinWeightThreshold`, and `(max - min) <= WeightStabilityThreshold * 2`; set `StableWeight = (min + max) / 2`
- [x] 1.3 Keep `DistinctUntilChanged(IsStable)` + `Replay(1).RefCount()`; Debug log periods / range / counts

## 2. Dual path sync

- [x] 2.1 Apply the same downsample + full-window rules to `AttendedWeighingService` inline `stabilityStream` (StableWeight for record creation)
- [x] 2.2 Confirm status path (`CreateStabilityStream`) and record path use identical stability predicates

## 3. Tests

- [x] 3.1 Update `WeighingStabilityPrematureLockReproductionTests`: mid-ascent 0.54~0.55 plateau under full window MUST NOT become `IsStable` (invert old characterization)
- [x] 3.2 Add/assert full `periods` stable platform (e.g. ~1.05t) CAN become `IsStable` with `StableWeight` near that platform
- [x] 3.3 Cover insufficient periods / below-threshold in window / range over threshold → `IsStable=false`

## 4. Verify

- [x] 4.1 Run MaterialClient unit tests for the stability / premature-lock suite
- [x] 4.2 Smoke: with 3000/200 config, ascending short plateau must not create a weighing record before ~3s of continuous above-threshold stability
