## Why

Urban 现场（2026-10-21）上磅爬升中途在约 0.54~0.55t 短平台即判 `IsStable` 并建单约 0.545t，真实终重约 1.05t。根因是稳定流吃高频原始点，且最少点数仅为 `max(8, window/interval×0.5)`，`StabilityWindowMs=3000` 只作回看窗、不作最短等待。产品期望必须等满全部窗口周期后再判稳。

调研落点：`docs/2026-10-21-weighing-stability-premature-lock/`。

## What Changes

- 稳定性流先按 `StabilityCheckIntervalMs` 降采样，再按 `periods = floor(StabilityWindowMs / StabilityCheckIntervalMs)` 滑窗判稳
- 仅当窗口凑满 `periods` 点、全部 `> MinWeightThreshold`、且极差 ≤ `WeightStabilityThreshold × 2` 时 `IsStable=true`
- 同步修改 `WeighingStreamPipeline.CreateStabilityStream` 与 `AttendedWeighingService` 内联稳定流
- 更新 `attended-weighing` 规范；将过早锁重复现单测改为「满窗前不得稳」回归

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `attended-weighing`: 稳定性流须等满全部窗口周期；降采样后按完整 `window/interval` 判稳

## Impact

- **MaterialClient**：`WeighingStreamPipeline`、`AttendedWeighingService`、相关单测
- 默认 3000/200 配置下，上磅后至少约 3s 才可能判稳；爬升中途短平台不再提前建单
- 配置项名称与默认值不变；判稳变严（符合产品期望）
