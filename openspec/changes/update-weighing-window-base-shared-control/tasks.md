## 1. 共享基础控件实现

- [x] 1.1 在 `repos/MaterialClient/src/MaterialClient.UI/Controls/` 新增 `WeighingWindowBase.axaml`，实现四行基础布局（标题栏、重量区、内容区、状态栏）。
- [x] 1.2 在 `repos/MaterialClient/src/MaterialClient.UI/Controls/WeighingWindowBase.axaml.cs` 定义可绑定属性与插槽（菜单项、内容区、显示开关）并完成默认值设置。
- [x] 1.3 在 `WeighingWindowBase` 中实现标题栏拖动、最小化、关闭等事件转发接口，供承载窗口沿用原有处理逻辑。
- [x] 1.4 校准共享样式资源（必要时更新 `SharedTheme.axaml`），确保标题栏与状态栏风格可被主窗口和 Urban 窗口统一复用。

## 2. 主应用窗口重构（AttendedWeighingWindow）

- [x] 2.1 重构 `repos/MaterialClient/src/MaterialClient/Views/AttendedWeighing/AttendedWeighingWindow.axaml`，改为基于 `WeighingWindowBase` 组合原有菜单与三列内容。
- [x] 2.2 更新 `AttendedWeighingWindow.axaml.cs` 事件接线，确保标题栏拖动和窗口控制按钮行为与改造前一致。
- [x] 2.3 验证主窗口现有绑定、命令和交互路径无行为变化（菜单入口、重量区显示、主内容操作、底部状态栏）。

## 3. Urban 窗口重构（UrbanAttendedWeighingWindow）

- [x] 3.1 重构 `repos/MaterialClient/src/MaterialClient.Urban/Views/UrbanAttendedWeighingWindow.axaml`，改为基于 `WeighingWindowBase` 组合 Urban 菜单和内容布局。
- [x] 3.2 更新 `UrbanAttendedWeighingWindow.axaml.cs` 事件接线，确保窗口拖动、最小化、关闭和菜单行为保持兼容。
- [x] 3.3 对齐 Urban 标题栏与主应用样式，确认重量区与状态栏风格满足统一规范。

## 4. 回归验证与收尾

- [ ] 4.1 分别执行主窗口与 Urban 窗口手动回归：窗口打开、菜单点击、重量显示、状态栏更新、拖动、最小化、关闭。
- [ ] 4.2 对比重构前后 UI 行为，确认无功能回归且视觉风格统一。
- [ ] 4.3 完成 OpenSpec 任务勾选与变更状态复核，为 `/opsx:apply` 实施阶段提供可执行基线。
