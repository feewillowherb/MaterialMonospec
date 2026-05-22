## Context

当前主应用与 Urban 应用的称重窗口都采用四行结构（标题栏、重量区、内容区、状态栏），但在不同 XAML 中重复实现，导致样式一致性和维护效率问题。  
本次变更限定为 UI 结构重构：不改变 ViewModel 接口、不改变业务流程、不引入新外部依赖，仅在 `MaterialClient.UI` 引入共享基类控件并在两个窗口中复用。

约束：
- 必须继续兼容现有数据绑定与事件处理路径。
- Urban 与主应用标题栏样式需统一。
- OpenSpec 工件位于主仓库；代码实现仍在 `repos/MaterialClient` 子仓库。

## Goals / Non-Goals

**Goals:**
- 提供 `WeighingWindowBase`，抽象并复用四行布局骨架。
- 通过可配置属性/内容插槽支持主窗口与 Urban 窗口差异化 UI 组合。
- 在保持行为不变前提下，减少重复 XAML，降低样式漂移风险。
- 为后续新增称重窗口提供统一复用入口。

**Non-Goals:**
- 不修改任何称重业务规则、状态机或设备交互逻辑。
- 不调整 ViewModel 公共契约（属性/命令语义保持不变）。
- 不在本变更中引入新的自动化测试框架或非必要技术债清理。

## Decisions

### Decision 1: 以 `UserControl` 形式实现 `WeighingWindowBase`
- 选择：在 `MaterialClient.UI/Controls` 新增 `WeighingWindowBase.axaml(.cs)`，承载统一四行布局。
- 理由：与现有 `DeviceStatusBar` 等共享控件一致，易于跨主应用和 Urban 应用复用，且无需改变窗口生命周期管理方式。
- 备选方案：提取为样式模板/资源字典。  
  - 未选原因：仅靠样式模板难以表达结构插槽和事件转发，维护复杂度更高。

### Decision 2: 通过参数化 + 内容插槽支持差异化
- 选择：提供可绑定参数（如 `ShowWeightDisplay`、`ShowDeliveryTypeSelector`）和 `MenuItems`/`ContentArea` 插槽，承载主窗口与 Urban 窗口不同菜单与内容布局。
- 理由：最大化复用外层结构，同时保留窗口内部业务 UI 灵活性。
- 备选方案：两个独立基础控件（主版/Urban 版）。  
  - 未选原因：会重新引入重复与分叉，不满足统一目标。

### Decision 3: 保持 ViewModel 与事件契约不变
- 选择：基础控件仅做 UI 结构聚合和事件转发，窗口 code-behind 继续持有原有事件处理入口（例如标题栏拖动、按钮事件）。
- 理由：降低回归风险，确保“重构不改行为”。
- 备选方案：同时重构 ViewModel 与命令绑定。  
  - 未选原因：超出本变更范围，风险和验证成本显著上升。

### Decision 4: 标题栏与状态栏样式统一到共享实现
- 选择：主窗口与 Urban 窗口共用基础控件中的标题栏和底部状态栏结构，必要时通过共享样式资源补齐差异。
- 理由：解决当前视觉不一致，后续样式调整只需改一处。
- 备选方案：保留各自标题栏，仅提取重量区和状态栏。  
  - 未选原因：无法彻底解决样式漂移根因。

## Risks / Trade-offs

- [绑定回归] 重构后若插槽 DataContext 传递异常，可能导致部分绑定失效  
  → Mitigation：保持原绑定路径，逐窗口做加载、交互和数据刷新回归。

- [事件转发遗漏] 标题栏拖动、窗口控制按钮等事件若映射不完整会影响可用性  
  → Mitigation：在基础控件提供显式事件并在两个窗口 code-behind 逐项接线验证。

- [样式耦合提升] 共享后单点样式改动同时影响两窗口  
  → Mitigation：将差异化需求参数化，避免硬编码；变更前进行双窗口视觉检查。

- [短期迁移成本] 首次抽象会增加一次性重构与联调成本  
  → Mitigation：按“基础控件 -> 主窗口 -> Urban 窗口”分阶段迁移并逐阶段验证。

## Migration Plan

1. 在 `MaterialClient.UI` 新增 `WeighingWindowBase`，完成基础布局、插槽和事件转发。
2. 重构 `AttendedWeighingWindow` 接入基础控件，保持原功能行为。
3. 重构 `UrbanAttendedWeighingWindow` 接入基础控件并统一标题栏样式。
4. 执行窗口级手动回归（菜单、称重显示、状态栏、拖动/最小化/关闭）。
5. 回滚策略：若出现不可接受回归，可按窗口维度回退到改造前 XAML（保留 Git 历史）。

## Open Questions

- `WeighingWindowBase` 中 `MenuItems` 是否采用 `ItemsControl` + DataTemplate（推荐）还是直接内容插槽（实现更快但扩展性较弱）？
- 主窗口与 Urban 的重量区细节差异是否全部参数化，还是允许少量局部模板覆盖？
