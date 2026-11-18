## Context

现场与复现证据见 `docs/2026-10-21-weighing-stability-premature-lock/`。现行 `CreateStabilityStream`（及 `AttendedWeighingService` 内联副本）对原始秤流做 `Buffer(StabilityWindowMs, StabilityCheckIntervalMs)`，有效点 ≥ `max(8, window/interval×0.5)` 且极差 ≤ `threshold×2` 即 `IsStable`。高频采样下爬升短平台可在远小于 3000ms 内锁重。

产品期望：必须等满 `StabilityWindowMs / StabilityCheckIntervalMs` 全部窗口期。

## Goals / Non-Goals

**Goals:**

- 默认 3000/200 下，至少约 3000ms 连续有效、极差合格后才可 `IsStable=true`
- 点数与时间对齐：降采样后 `periods = max(1, floor(windowMs/intervalMs))`
- 双路径（Pipeline + Service 内联）算法一致；规范与单测一致

**Non-Goals:**

- 不改配置 UI / 配置项名称与默认值
- 不做上升趋势检测、峰值后再锁、锁后随涨改写（可另开 change）
- 不在本 change 合并两处实现为单一类型（可选后续 refactor；本 change 只保证逻辑一致）

## Decisions

### 1. 先降采样，再按完整周期数滑窗

**选择**：与 `CreateWeightStream` 同构——先 `Buffer(intervalMs)` 取 `Last()`；再滑动窗口 `periods` 个降采样点上做有效性与极差判定。

**理由**：仅提高 `minDataPoints` 而不降采样时，高频原始点仍可亚秒凑满点数。降采样后 15 点 ≈ 15×200ms ≈ 3000ms。

### 2. 满窗 + 全部有效 + 极差

**选择**：

```text
periods = max(1, floor(StabilityWindowMs / StabilityCheckIntervalMs))
IsStable <=> downsampledWindow.Count == periods
         && downsampledWindow.All(w => w > MinWeightThreshold)
         && (max - min) <= WeightStabilityThreshold * 2
StableWeight = IsStable ? (min + max) / 2 : null
```

窗口内任一 ≤阈值样本 → 不稳（开放问题 #1：按产品倾向写死）。

### 3. 双路径同步

**选择**：同一算法同时改 `WeighingStreamPipeline.CreateStabilityStream` 与 `AttendedWeighingService` 内联 `stabilityStream`。

**理由**：状态转换与建单 `StableWeight` 各用一路；只改一路会漂移。

### 4. 单测策略

**选择**：改写 `WeighingStabilityPrematureLockReproductionTests`：旧「亚秒锁 0.545」应变为失败期望（满窗前 `IsStable=false`）；另加满窗后于稳定平台可 `IsStable=true`。Urban/Attended 共用管道，同一 change 覆盖。

### 5. 配置边界

**选择**：`periods < 1` 时按 1 处理并可打 Warning；不在本 change 强制配置保存校验。

## Risks / Trade-offs

- [判稳变慢] → 符合期望；嫌慢则调小 `StabilityWindowMs`，勿改回半窗点数
- [串口某 200ms 桶为空] → 该周期无点则未满 `periods`，延后判稳（偏安全）
- [双份代码仍存在] → 接受短期重复；以 tasks 明确两处同改，避免漂移

## Migration Plan

- 仅 MaterialClient 逻辑 + 单测 + monospec delta spec；无 DB/API 迁移
- 回滚：恢复旧稳定流实现即可

## Open Questions

（无 — 开放问题已按调研倾向在 Decisions 中拍板）
