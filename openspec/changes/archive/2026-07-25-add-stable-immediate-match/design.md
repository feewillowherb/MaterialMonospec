## Context

有人值守称重流水线在 `AttendedWeighingService` 中驱动状态机：`OffScale` → `WaitingForStability` → `WeightStabilized` → `WaitingForDeparture` → `OffScale`。

当前匹配时机：

1. `WeightStabilized`：`OnWeightStabilizedAsync` 创建 `WeighingRecord`（写入当前推荐车牌），**不**发布 `TryMatchEvent`
2. 进入 `OffScale`：`RewriteAndResetCycleAsync` → `TryReWritePlateNumberAsync` →（非 UrbanMode）发布 `TryMatchEvent`

运单匹配由 `TryMatchEventHandler` → `WeighingMatchingService.AutoMatchAsync` 消费。已匹配记录（`MatchedId != null`）会被 `AutoMatchAsync` 直接跳过。UrbanMode 通过 `IWeighingPipelineStrategy.ShouldSkipWaybillMatching()` 跳过发布。

配置落在 `WeighingConfiguration`（JSON 持久化于 `SettingsEntity.WeighingConfigurationJson`），设置 UI 在 `SettingsWindow` 称重参数区。

## Goals / Non-Goals

**Goals:**

- 新增 `EnableMatchOnStable`（默认 `false`）及设置 UI「稳定后立即匹配」
- 开启且稳定创建记录后若推荐车牌非空，立即发布 `TryMatchEvent`
- **稳定时已匹配成功 → 下磅不再发布 `TryMatchEvent`**
- **稳定时未能匹配（未尝试或未配上）→ 下磅兜底发布 `TryMatchEvent`**
- 下磅仍执行车牌重写与周期重置（与是否再匹配无关）
- 关闭开关：行为与现网一致
- UrbanMode 继续跳过 `TryMatchEvent`
- 保存设置后运行时可刷新该开关

**Non-Goals:**

- 不在下磅因车牌重写而 `Unmatch` 再重配（用户明确：已匹配则下磅不再匹配）
- 不改 `AutoMatchAsync` 配对算法本身
- 不改 UrbanMode 异常检测、LPR late-bind、主动抓拍
- 不把匹配提前到 `WaitingForStability`

## Decisions

### Decision 1：配置属性名与默认值

**方案**: `WeighingConfiguration.EnableMatchOnStable`（`bool`，默认 `false`）。

**理由**: 与现有开关命名一致；默认关闭保证向后兼容。

### Decision 2：稳定后触发挂点

**方案**: `IWeighingRecordService.TryPublishMatchOnStableAsync(WeighingStateManager)`，由 `OnWeightStabilizedAsync` 在 `CreateWeighingRecordAsync` 成功后调用：

1. `EnableMatchOnStable == false` → return
2. 无本周期 `recordId` → return
3. 推荐/记录车牌空白 → return（留给下磅兜底）
4. `ShouldSkipWaybillMatching()` → 跳过并打日志
5. 否则发布 `TryMatchEvent(recordId)`

**理由**: 匹配发布与 UrbanMode 策略集中在 `WeighingRecordService`。

### Decision 3：下磅是否再匹配（核心规则）

**方案**: 当 `EnableMatchOnStable == true` 时，`TryReWritePlateNumberAsync` 在发布 `TryMatchEvent` 前读取该记录：

- `MatchedId != null`（稳定时已匹配成功）→ **跳过**发布，打 debug/info 日志
- `MatchedId == null`（稳定时无车牌未试、或试过未配上）→ **照常**发布（兜底）

当 `EnableMatchOnStable == false` 时，下磅发布逻辑与现网完全一致（不新增跳过分支）。

车牌重写、DeliveryType 重写、`ClearCache`、`ResetCycle` 在两种情况下都照常执行。

**判定依据**: 以持久化字段 `WeighingRecord.MatchedId` 为准，不另建周期级「已尝试匹配」标志。

| 稳定阶段 | `MatchedId`（下磅时） | 下磅 `TryMatch` |
|----------|----------------------|-----------------|
| 开关关 | — | 现网：始终发 |
| 有车牌且配上 | 非空 | 跳过 |
| 有车牌但未配上 | 空 | 兜底发 |
| 无车牌未提前试 | 空 | 兜底发 |

**理由**: 满足「匹配过了就不再匹配、无法匹配才下磅兜底」；复用已有匹配结果字段，无额外状态机。

**替代方案（否决）**: 下磅一律再发、靠 `AutoMatchAsync` 短路 — 语义含糊，且无法表达「显式跳过」；车牌变更后也无法重配（与用户期望一致地放弃重配，但应在发布侧明确跳过）。

### Decision 4：有车牌判定

**方案**: 创建时推荐车牌 / 记录 `PlateNumber` 非空白才提前匹配。

### Decision 5：UI

**方案**: 称重参数区 `ToggleSwitch`「稳定后立即匹配」，绑定 `EnableMatchOnStable`。

### Decision 6：运行时刷新

**方案**: `UpdateRuntimeConfigurationAsync` 刷新 `_enableMatchOnStable`；稳定分支与下磅跳过分支均能读到最新值（下磅跳过也可每次从 settings/`MatchedId` 判断，不依赖缓存字段）。

## Risks / Trade-offs

- **[风险] 稳定时车牌不准导致错配，下磅改写车牌也不再重配** → 按产品选择接受；默认关闭；可与「启用车牌重写」运维上搭配使用
- **[风险] 稳定匹配事件尚未完成就极快下磅** → 实务上下磅远晚于稳定；若竞态导致仍发一次，`AutoMatchAsync` 对已匹配仍安全短路
- **[取舍] 不用「是否发布过 TryMatch」而用 `MatchedId`** → 「发过但未配上」仍会下磅兜底，符合「无法匹配才兜底」

## Migration Plan

1. 发布含新字段的客户端；旧 JSON 无字段 → `false`
2. 需要提前匹配的站点手动开启
3. 回滚：关开关或回退版本，无 schema migration

## Open Questions

- 无
