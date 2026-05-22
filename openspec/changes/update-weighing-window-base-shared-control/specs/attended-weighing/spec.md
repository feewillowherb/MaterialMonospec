## ADDED Requirements

### Requirement: 有人值守窗口复用共享基础控件
`AttendedWeighingWindow` MUST 通过 `WeighingWindowBase` 复用统一外层布局，并将原有菜单、重量区和主内容区作为插槽内容注入。

#### Scenario: 主窗口接入共享布局后功能不变
- **WHEN** 用户打开 `AttendedWeighingWindow`
- **THEN** 系统 SHALL 显示与改造前等价的菜单、重量显示区、主内容区和状态栏
- **AND** 所有既有绑定与命令执行结果 SHALL 与改造前一致

### Requirement: 有人值守窗口保持原有交互行为
在接入共享基础控件后，`AttendedWeighingWindow` 的标题栏拖动、窗口控制和菜单入口行为 MUST 保持兼容。

#### Scenario: 标题栏拖动行为兼容
- **WHEN** 用户在主窗口标题栏拖动窗口
- **THEN** 窗口 SHALL 与改造前一致地响应拖动，不得出现不可拖动或拖动区域失效

#### Scenario: 菜单与窗口按钮行为兼容
- **WHEN** 用户点击主窗口菜单项、最小化按钮或关闭按钮
- **THEN** 系统 SHALL 触发与改造前一致的事件处理路径与结果
