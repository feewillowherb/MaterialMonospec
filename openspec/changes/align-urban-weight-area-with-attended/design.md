## Context

`WeighingWindowBase` 的 `WeightAreaContent` 插槽由宿主窗口注入内容。`AttendedWeighingWindow` 使用横幅背景 + `Margin 24,32` + 左车牌（`MostFrequentPlateNumber`）+ 中栏重量卡（含 DeliveryType）+ 右栏 `CurrentWeighingStatusText` 与 `LoadingDotsAnimation`。`UrbanAttendedWeighingWindow` 当前为渐变背景 + `Margin 24,0` + 左装饰块 + 简化重量 StackPanel + `WeightStatus`/`WeightStatusColor`。

Urban 与 Attended 共用 `WeighingRecordService` 创建记录时的 `GetMostFrequentPlateNumber()`，但 Urban ViewModel 未订阅车牌变更 MessageBus，称重区也未展示实时车牌。

## Goals / Non-Goals

**Goals:**

- 称重区**内容结构**与 Attended 一致（三列、边距、重量样式、右侧状态 + 动画）
- 应用对齐项 **1–3**（边距、重量 F2/64/单位竖线、右侧 Attended 状态模型）
- ViewModel 暴露与 Attended 称重区相同的绑定面（车牌、状态文案、称重中动画）
- `LoadingDotsAnimation` 可被 Urban 通过 `MaterialClient.UI` 引用

**Non-Goals:**

- 不更换 Urban 称重区**背景**（保持 `LinearGradientBrush`，不用 `Indexbanner.png`）
- 不实现 DeliveryType 收/发料、通知 Inlines、省份业务逻辑扩展
- 不重构 `WeighingWindowBase` 或抽取共享 XAML 用户控件（本 change 仅改 Urban 窗口 + 必要控件迁移）
- 不在此 change 内完成列表「车牌号码」筛选 TextBox 绑定（可记为 follow-up）

## Decisions

### 1. 以 Attended 为视觉与绑定基准（去掉 DeliveryType 列）

中栏 `#5A7FE6` 圆角 `Border` 内使用 `Grid` **仅保留重量 + 单位列**（无 `AnimatedDeliveryTypeRadioButton`、无 `DeliveryTypeNotification`）。重量 `TextBlock` 与 Attended 相同：`StringFormat F2`、`FontSize 64`、`Margin` 可收窄（无 DeliveryType 列时去掉 `70,0,70,0` 过大左右留白，改为居中 `Margin 24,0` 或等效）。

**理由**：用户明确要求称重内容与 Attended 一致且排除 DeliveryType。

### 2. 左侧改为 `MostFrequentPlateNumber` 卡片

复制 Attended 左栏 `Border`（`Padding 20,12`、`CornerRadius 8`、`TranslateTransform X=-60`），绑定 `MostFrequentPlateNumber`。

ViewModel 在 `Initialize()` 中：

- 读取 `_attendedWeighingService.GetMostFrequentPlateNumber()`
- 订阅 `MessageBus` 的 `PlateNumberChangedMessage`（与 Attended 相同）

**理由**：与 LPR 实时会话一致；列表 `PlateNumber` 仍为历史快照，职责分离不变。

### 3. 右侧改为 `CurrentWeighingStatusText` + `LoadingDotsAnimation`

移除称重区对 `WeightStatus` / `WeightStatusColor` 的绑定。由 `StatusChangedEventData` 更新 `_currentWeighingStatus` 并 `RaisePropertyChanged` 计算属性：

- `CurrentWeighingStatusText` — 复用 Attended 的 `GetStatusText(AttendedWeighingStatus)` 文案映射（可抽到 `MaterialClient.Common` 静态帮助类避免引用 MaterialClient ViewModels）
- `IsWeighingActive` — `status != OffScale`

XAML 复制 Attended 的 `Margin="-150,0,0,0"` 与 `LoadingDotsAnimation` `Margin="-75,0,0,0"`。

**理由**：对齐项 3；Urban 称重区不再使用彩色状态字。

### 4. 边距与拉伸（对齐项 1）

内容层 `Grid` 使用 `Margin="24,32"`、`HorizontalAlignment="Stretch"`、`VerticalAlignment="Stretch"`，外层保留 Urban 现有渐变 `Border` 包裹。

### 5. `LoadingDotsAnimation` 迁至 `MaterialClient.UI`

将 `LoadingDotsAnimation` 从 `MaterialClient.Views.Controls` 移到 `MaterialClient.UI.Controls`（或 `MaterialClient.UI.Views.Controls`），更新 Attended 与 Urban 的 xmlns。Urban 已引用 `MaterialClient.UI`。

**替代方案**：Urban 引用 `MaterialClient` 项目 — 拒绝，耦合过重。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 控件迁移导致 Attended 编译/XAML 路径变更 | 仅改命名空间与引用，行为不变；构建两个入口 |
| 去掉彩色 `WeightStatusColor` 后 Urban 操作员习惯变化 | 与 Attended 一致；列表区仍可用 `IsAnomaly` 徽章 |
| 中栏无 DeliveryType 后水平留白需微调 | 设计阶段对照 Attended 截图调 `Margin`/`MinWidth` |
| `GetStatusText` 重复 | 提取 `AttendedWeighingStatusDisplay` 至 Common |

## Migration Plan

1. 迁移 `LoadingDotsAnimation` → 更新 Attended 引用 → 扩展 Urban ViewModel → 替换 Urban `WeightAreaContent` XAML
2. 手动验证：LPR 识别后左栏车牌更新；称重中右侧白字 + 动画；重量 F2；背景仍为渐变
3. 无数据库变更

## Open Questions

- 无（中栏水平 margin 以实现对齐 Attended 视觉为准，实现时微调）
