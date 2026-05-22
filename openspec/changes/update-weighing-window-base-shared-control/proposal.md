## Why

当前 `AttendedWeighingWindow` 与 `UrbanAttendedWeighingWindow` 分别维护相似的四行布局和标题栏结构，导致同类 UI 变更需要双份维护，且已出现样式漂移。现在引入共享基础控件可以在不改变业务逻辑的前提下统一样式与布局，降低后续维护成本。

## What Changes

- 在 `MaterialClient.UI` 新增可复用的 `WeighingWindowBase` 基础控件，抽象标题栏、重量区、内容区和底部状态栏四行结构。
- 将 `AttendedWeighingWindow` 重构为基于 `WeighingWindowBase` 组合其菜单和三列内容区域，保持现有功能与交互不变。
- 将 `UrbanAttendedWeighingWindow` 重构为基于 `WeighingWindowBase` 组合其菜单和内容区域，统一与主窗口的标题栏样式与布局规范。
- 统一两类窗口在标题栏/重量区/状态栏上的共享样式约束，减少重复 XAML 和后续样式分叉风险。

## Capabilities

### New Capabilities
- `weighing-window-base-layout`: 提供称重窗口可复用的基础四行布局控件与可配置插槽（菜单项、内容区、显示开关）。

### Modified Capabilities
- `attended-weighing`: 有人值守主窗口界面结构改为复用共享基础控件，并保持现有行为一致。
- `materialclient-urban-desktop`: Urban 主窗口界面结构改为复用共享基础控件，并与主窗口标题栏样式保持一致。

## Impact

- 影响代码：
  - `repos/MaterialClient/src/MaterialClient.UI/Controls/`（新增基础控件）
  - `repos/MaterialClient/src/MaterialClient/Views/AttendedWeighing/`（主窗口重构）
  - `repos/MaterialClient/src/MaterialClient.Urban/Views/`（Urban 窗口重构）
- 对 ViewModel、业务流程、设备交互和外部 API 无功能变更。
- 主要风险为 UI 绑定和样式迁移回归，需要通过窗口交互与视觉一致性回归验证。
