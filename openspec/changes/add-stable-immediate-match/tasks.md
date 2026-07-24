## 1. Configuration

- [ ] 1.1 在 `WeighingConfiguration` 中新增 `EnableMatchOnStable`（`bool`，默认 `false`）
- [ ] 1.2 确认旧 JSON 缺字段反序列化为 `false`（无需 migration）

## 2. Settings UI

- [ ] 2.1 在 `SettingsWindowViewModel` 新增 `[Reactive] EnableMatchOnStable` 属性
- [ ] 2.2 在 Load/Save 中与 `WeighingConfiguration.EnableMatchOnStable` 同步
- [ ] 2.3 在 `SettingsWindow.axaml` 称重参数区新增「稳定后立即匹配」`ToggleSwitch`

## 3. Service Logic

- [ ] 3.1 在 `IWeighingRecordService` / `WeighingRecordService` 新增 `TryPublishMatchOnStableAsync`：读开关、校验记录与非空车牌、尊重 `ShouldSkipWaybillMatching()` 后发布 `TryMatchEvent`
- [ ] 3.2 在 `AttendedWeighingService.OnWeightStabilizedAsync` 创建记录成功后调用上述方法
- [ ] 3.3 修改 `TryReWritePlateNumberAsync`：当 `EnableMatchOnStable == true` 且记录 `MatchedId != null` 时跳过发布 `TryMatchEvent`；`MatchedId == null` 时仍兜底发布；`EnableMatchOnStable == false` 保持现网
- [ ] 3.4 缓存并在 `UpdateRuntimeConfigurationAsync` 中刷新 `EnableMatchOnStable`
- [ ] 3.5 确认下磅仍执行车牌重写与 `RewriteAndResetCycleAsync` 周期重置（与是否再匹配无关）

## 4. Tests

- [ ] 4.1 开关开启 + 有车牌：稳定创建后发布 `TryMatchEvent`
- [ ] 4.2 开关开启 + 稳定已匹配（`MatchedId` 非空）：下磅不发布 `TryMatchEvent`
- [ ] 4.3 开关开启 + 稳定未匹配（无车牌或未配上）：下磅兜底发布 `TryMatchEvent`
- [ ] 4.4 开关关闭：稳定阶段不发布；下磅按现网发布
- [ ] 4.5 UrbanMode / `ShouldSkipWaybillMatching=true`：稳定与下磅均不发布
