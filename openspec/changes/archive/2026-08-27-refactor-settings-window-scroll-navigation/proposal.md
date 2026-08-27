## Why

`SettingsWindow` 右侧用「长页 StackPanel + ScrollViewer」配合 code-behind 手工维护分区锚点、`TranslatePoint` 打分与 `Offset` 跳转，实现 scroll-spy 双向同步。该方案脆弱（分区标题/正文分离导致锚点高度错误）、难维护（每增一节要改 AXAML 与两处字典），且与 Avalonia 推荐的「约束视口内滚动 / `BringIntoView`」用法不符。城管配置等新区已暴露布局与选中时序问题，需要换成可扩展的导航方案。

## What Changes

- 将设置窗右侧从「单页长滚动 + 滚动联动导航」改为「左侧导航选择分区 → 右侧仅展示当前分区」；每个分区在约束高度的 `ScrollViewer` 内独立滚动。
- 移除（或大幅精简）`SettingsWindow.axaml.cs` 中的分区锚点字典、`Offset` 节流监听、`TranslatePoint` 打分与导航点击延时互斥逻辑。
- 保留现有各分区业务控件、绑定与 Urban 条件可见项（异常设置、城管配置等）；不改设置字段语义与保存流程。
- **BREAKING（交互）**：不再支持在右侧连续滚动时自动高亮左侧导航；切换分区以点击导航为主。

## Capabilities

### New Capabilities

- `settings-window-section-navigation`: 设置窗左侧分区导航与右侧单区内容切换、每区独立滚动的行为契约。

### Modified Capabilities

- `settings-ui`: 将「可滚动的右侧整页内容」要求改为「按导航切换分区，分区内可滚动」。

## Impact

- `repos/MaterialClient/src/MaterialClient.UI/Views/SettingsWindow.axaml` / `SettingsWindow.axaml.cs`
- 可能轻微触及 `SettingsWindowViewModel`（若增加当前分区选中状态绑定）；不改 `ISettingsService` / 持久化模型
- 主程序 / Urban / Recycle 共用同一 `SettingsWindow`；需回归分区切换与保存
