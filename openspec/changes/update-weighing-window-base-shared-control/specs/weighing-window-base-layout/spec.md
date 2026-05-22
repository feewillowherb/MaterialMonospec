## ADDED Requirements

### Requirement: 共享称重窗口基础布局控件
系统 MUST 在 `MaterialClient.UI` 提供 `WeighingWindowBase` 共享控件，统一封装称重窗口四行结构：标题栏、重量显示区、主内容区、底部状态栏。

#### Scenario: 基础控件渲染四行结构
- **WHEN** 任一窗口使用 `WeighingWindowBase` 作为根布局
- **THEN** 系统 SHALL 按顺序渲染标题栏（Row 0）、重量区（Row 1）、内容区（Row 2）、状态栏（Row 3）

### Requirement: 基础控件支持可配置插槽与显示开关
`WeighingWindowBase` MUST 提供菜单项和内容区注入能力，并通过布尔配置控制重量区与配送类型区域显示，满足不同业务窗口复用。

#### Scenario: 主窗口注入完整菜单与内容
- **WHEN** `AttendedWeighingWindow` 使用 `WeighingWindowBase`
- **THEN** 系统 SHALL 允许注入完整菜单项集合与三列主内容布局
- **AND** SHALL 保持重量区和配送类型选择器可见

#### Scenario: Urban 窗口注入简化菜单与内容
- **WHEN** `UrbanAttendedWeighingWindow` 使用 `WeighingWindowBase`
- **THEN** 系统 SHALL 允许注入简化菜单项集合与 Urban 专用内容布局
- **AND** SHALL 允许根据配置隐藏不需要的配送类型选择器

### Requirement: 基础控件转发窗口交互事件
`WeighingWindowBase` MUST 暴露并转发标题栏拖动、窗口控制按钮等交互事件，确保窗口行为与改造前一致。

#### Scenario: 标题栏拖动事件透传
- **WHEN** 用户在 `WeighingWindowBase` 标题栏按住左键拖动
- **THEN** 承载窗口 SHALL 接收到可用于 `BeginMoveDrag` 的事件参数

#### Scenario: 窗口控制按钮事件透传
- **WHEN** 用户点击最小化或关闭按钮
- **THEN** 承载窗口 code-behind SHALL 接收到对应事件并执行原有处理逻辑
