## Why

有人值守称重当前仅在进入 `AttendedWeighingStatus.OffScale`（下磅）后，通过 `RewriteAndResetCycleAsync` → `TryReWritePlateNumberAsync` 发布 `TryMatchEvent` 触发运单匹配。车辆在磅上已稳定且已有车牌时，仍需等到下磅才能匹配，拉长了列表可见匹配结果与后续操作的等待时间。需要一个可配置开关，在「重量稳定且已有车牌」时提前匹配；若稳定时已匹配成功，下磅不再重复匹配，仅在稳定时未能匹配时由下磅兜底。

## What Changes

- 在 `WeighingConfiguration` 中新增布尔开关 `EnableMatchOnStable`（默认 `false`，向后兼容）
- 在设置窗口称重参数区域新增「稳定后立即匹配」`ToggleSwitch`
- 开启后：进入 `WeightStabilized` 并成功创建称重记录后，若当前推荐车牌非空，立即发布 `TryMatchEvent`（仍尊重 UrbanMode 跳过匹配策略）
- 开启且稳定时已匹配成功（`MatchedId` 非空）：下磅仍做车牌重写与周期重置，但 **不再** 发布 `TryMatchEvent`
- 开启但稳定时未能匹配（无车牌未尝试，或尝试后仍未配上）：下磅按既有路径兜底发布 `TryMatchEvent`
- 关闭时：行为与现网一致，仅在 `OffScale` 后匹配

## Capabilities

### New Capabilities

- `stable-immediate-match`: 称重参数中的「稳定后立即匹配」开关；定义稳定提前匹配与下磅兜底/跳过规则

### Modified Capabilities

- `attended-weighing`: 补充稳定后提前匹配的触发时机、下磅按 `MatchedId` 决定是否再匹配，以及运行时配置刷新覆盖新开关

## Impact

- `repos/MaterialClient`（MaterialClient 子仓库）
  - `MaterialClient.Common/Configuration/WeighingConfiguration.cs` — 新增属性
  - `MaterialClient.Common/Services/AttendedWeighing/AttendedWeighingService.cs` — 稳定后触发提前匹配；运行时刷新新开关
  - `MaterialClient.Common/Services/AttendedWeighing/WeighingRecordService.cs` — 稳定后匹配发布；下磅发布前按 `MatchedId` 跳过
  - `MaterialClient.UI/ViewModels/SettingsWindowViewModel.cs` — 绑定与持久化
  - `MaterialClient.UI/Views/SettingsWindow.axaml` — 称重参数 UI 开关
  - 相关单元测试（稳定有车牌提前匹配、已匹配下磅不发、未匹配下磅兜底、开关关闭走原路径）
- UrbanManagement：无代码变更
- 持久化：经现有 `WeighingConfigurationJson` JSON 序列化，无需额外 DB migration；旧配置缺字段反序列化为 `false`
