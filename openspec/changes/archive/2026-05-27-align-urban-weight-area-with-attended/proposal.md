## Why

Urban 有人值守窗口的 `WeightAreaContent` 仍使用简化布局（装饰左块、48 号字、彩色状态文案），与主程序 `AttendedWeighingWindow` 的称重区体验不一致，操作员在不同产品间切换时易产生认知负担。需要在**保留 Urban 渐变背景**、**不包含收/发料（DeliveryType）** 的前提下，对齐边距、重量展示与右侧状态区，并复用 Attended 的实时车牌与称重状态呈现。

## What Changes

- 重构 `UrbanAttendedWeighingWindow.axaml` 的 `WeightAreaContent`：三列布局与 Attended 一致（左：当前识别车牌；中：圆角重量卡；右：状态文案 + 加载动画）
- 统一内容区 `Margin="24,32"` 与 `VerticalAlignment="Stretch"`（对齐项 1）
- 重量显示：`CurrentWeight` 使用 `{0:F2}`、字号 64、白色、单位「吨」24 + 竖线分隔（对齐项 2）；**不**包含 DeliveryType 选择器与相关通知
- 右侧：`CurrentWeighingStatusText`、白色 Bold 18、`LoadingDotsAnimation` 与 Attended 相同 margin（对齐项 3）；**不**使用 Urban 现有 `WeightStatus` / `WeightStatusColor` 双色徽章方案于称重区
- 扩展 `UrbanAttendedWeighingViewModel`：`MostFrequentPlateNumber`（`IPlateNumberService` / `PlateNumberChangedMessage`）、`CurrentWeighingStatusText`、`IsWeighingActive`（由已有 `StatusChangedEventData` 映射）
- 将 `LoadingDotsAnimation` 迁至 `MaterialClient.UI`（或等效共享位置），供 Urban 与 Attended 引用，避免 Urban 依赖整个 `MaterialClient` 程序集
- **不修改**称重区背景（Urban 保持横向渐变，不引入 `Indexbanner.png`）
- **不修改**列表明细、Tab、DTO 分页契约（除非 tasks 中车牌筛选绑定为独立小项）

## Capabilities

### New Capabilities

- `urban-weight-area-presentation`: Urban 称重区（`WeightAreaContent`）布局、绑定与 ViewModel 契约，与 Attended 对齐且排除 DeliveryType

### Modified Capabilities

- （无）`urban-weighing-list-presentation` 列表区行为不变

## Impact

- **子仓库**：`repos/MaterialClient`
  - `MaterialClient.Urban`：`UrbanAttendedWeighingWindow.axaml`、`UrbanAttendedWeighingViewModel.cs`
  - `MaterialClient`：`AttendedWeighingWindow.axaml`（`LoadingDotsAnimation` 命名空间/程序集引用调整，若控件迁移）
  - `MaterialClient.UI`：可选迁入 `LoadingDotsAnimation`
- **依赖**：现有 `IAttendedWeighingService`、`IPlateNumberService`、`PlateNumberChangedMessage`、`StatusChangedEventData`（Urban 已启动 `AttendedWeighingService`）
- **无** UrbanManagement / 数据库迁移
