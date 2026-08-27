## Context

`SettingsWindow`（`MaterialClient.UI`）当前布局为：左侧 `ListBox` 导航 + 右侧单一 `ScrollViewer` 内超长 `StackPanel` 堆叠全部设置分区。code-behind（`SettingsWindow.axaml.cs`）维护两套字典（导航项 / 分区控件），用 `ScrollViewer.Offset` 节流 + `TranslatePoint` 打分实现滚动高亮，用手动算 `Offset` + `Task.Delay` 互斥实现点击跳转。

问题：

1. **锚点与内容脱节**：分区标题 `Border` 与正文常分离；`x:Name` 挂在空标题上时滚动目标高度≈0（城管配置已踩坑）。
2. **扩展成本高**：新增分区需改 AXAML 两处 + code-behind 四处查找注册，易漏。
3. **与 Avalonia 文档不符**：[ScrollViewer how-to](https://docs.avaloniaui.net/docs/how-to/scrollviewer-how-to) 强调视口约束、`BringIntoView`、`ScrollChanged`；未推荐「长页 scroll-spy」。专家规则倾向导航容器切换内容，而非手工几何同步。
4. **竞态**：程序滚动与滚动监听互相打架，靠布尔旗 + 固定延时。

约束：保持 ReactiveUI / 现有 ViewModel 绑定；不改设置字段与保存语义；Urban 条件分区（异常、城管）仍只在 Urban 可见。

## Goals / Non-Goals

**Goals:**

- 左侧导航选择驱动右侧「当前分区」展示
- 每个分区在 `Grid` 约束高度下独立 `ScrollViewer` 滚动
- 删除 scroll-spy 与手工 Offset/TranslatePoint 同步
- 新增分区只需：导航项 + 一处内容宿主（声明式优先）

**Non-Goals:**

- 不重做各分区业务表单、DataGrid、测试按钮逻辑
- 不改 `SettingsEntity` / `UrbanSettingsJson` / 保存 LocalEvent
- 不引入 CommunityToolkit.Mvvm 替换 ReactiveUI
- 不实现「长页连续滚动 + 自动高亮」的保留兼容

## Decisions

### D1：导航切换单分区（首选）取代长页 scroll-spy

**决策**：右侧用 `ContentControl`（或等价：按选中 Tag 切换 `IsVisible` 的分区宿主）只显示当前导航对应分区；外层 `Grid` 行 `*` 约束高度，分区内自带 `ScrollViewer`。

**理由**：

- 消灭双向同步与锚点字典
- 符合 Avalonia「ScrollViewer 必须在有限高度容器内」的要求
- 与侧栏设置类产品交互一致；城管等长表单不再被长页几何计算连累

**备选 A — 保留长页，仅改用 `BringIntoView`**：仍需 scroll-spy 或放弃滚动高亮；维护成本只降一半，锚点结构问题仍在。拒绝作为主路径。

**备选 B — `TabControl`**：可用，但需重皮肤以匹配现有左侧 ListBox 视觉；成本高。可选实现细节，非必须。

### D2：选中状态归属

**决策**：优先用现有 `ListBox.SelectedItem` / `Tag` 驱动可见性或 `ContentControl` 内容；若需绑定更干净，可在 `SettingsWindowViewModel` 增加 `SelectedSettingsSection`（string/enum）并绑定，**不**把几何滚动逻辑放进 ViewModel。

**备选**：纯 code-behind 切换 `IsVisible` — 可接受为最小改动，但新增分区仍易漏；倾向声明式绑定。

### D3：滚动 API

**决策**：分区内滚动依赖用户手势与默认 `BringIntoViewOnFocusChange`；程序侧如需跳到控件（例如校验失败），调用目标控件 `BringIntoView()`（文档推荐），禁止再手算 `Offset`。

### D4：条件分区

**决策**：Urban 专属项继续 `IsVisible` 绑定；不可见项不得成为默认选中。打开窗口默认仍选「地磅设置」（或第一个可见非 Urban 专用项）。

### D5：底部保存按钮

**决策**：保持窗口级「确认保存」浮层/底栏不变；不随分区滚动消失（已在分区外 `Grid`）。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 用户习惯「一页滚完所有设置」 | 交互变更写进 spec；导航列表仍一目了然 |
| `IsVisible` 方案仍加载全部控件树 | 可接受（现状亦全量）；若性能不足再改 ContentControl/懒加载 |
| AXAML 大改冲突 | 单 PR 集中改 SettingsWindow；先迁结构再删 code-behind |
| 与未归档 `update-xiaoshan-upload-config-in-settings` 叠改 | 本 change 只动导航/滚动壳；城管表单内容原样迁入单区宿主 |

## Migration Plan

1. 在 `SettingsWindow.axaml` 引入单区宿主结构，把现有分区内容块原样搬入。
2. 用选中绑定切换可见性；验证各分区与保存。
3. 删除 `InitializeSectionTracking` 中的 Offset 监听、TranslatePoint、点击 Offset 跳转。
4. 冒烟：主程序 / Urban 打开设置、切换含条件分区、保存。

回滚：恢复长页 AXAML + 旧 code-behind（同文件 git revert）。

## Open Questions

无阻塞项。实现时可在「ContentControl + DataTemplate」与「多分区 IsVisible」之间选更少 diff 的一种，以 D1 行为为准。
