## 1. Shell — section host layout

- [x] 1.1 将 `SettingsWindow` 右侧从「单 ScrollViewer + 全部分区 StackPanel」改为「约束高度宿主 + 仅当前分区可见」结构（ContentControl 或按选中 Tag 的 IsVisible）
- [x] 1.2 为每个分区内容包一层分区内 `ScrollViewer`（父级 `Grid` `*` 约束高度，避免无限高度）
- [x] 1.3 保持窗口级「确认保存」底栏在分区滚动之外

## 2. Navigation wiring

- [x] 2.1 左侧 `ListBox` 选中驱动当前分区展示；打开默认选中地磅设置（或第一个可见项）
- [x] 2.2 Urban 条件项（异常设置、城管配置）保持 `IsVisible`；隐藏项不可作为默认选中
- [x] 2.3 如需更清晰绑定，在 ViewModel 增加 `SelectedSettingsSection`（string/enum）；几何滚动逻辑不得进入 ViewModel

## 3. Remove scroll-spy code-behind

- [x] 3.1 删除分区锚点字典、`Offset` 节流监听、`TranslatePoint` 打分、导航点击手工 `Offset` + `Task.Delay` 互斥
- [x] 3.2 保留关闭消息、LPR 列可见性等与滚动无关的 code-behind
- [x] 3.3 若需程序滚动到某控件，改用 `BringIntoView()`（不手算 Offset）

## 4. Verify

- [x] 4.1 编译 `MaterialClient.UI` / Urban；冒烟：切换各分区、长分区内滚动、保存/关闭
- [x] 4.2 确认主程序与 Urban 条件分区行为符合 spec；无 scroll-spy 回归需求
