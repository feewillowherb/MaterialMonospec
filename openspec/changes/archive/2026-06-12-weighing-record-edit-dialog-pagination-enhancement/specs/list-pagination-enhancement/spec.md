## ADDED Requirements

### Requirement: 首页导航按钮

`UrbanAttendedWeighingViewModel` SHALL 提供 `GoToFirstPageCommand`，将 `CurrentPage` 设为 1 并刷新列表。`UrbanAttendedWeighingWindow.axaml` 分页栏 SHALL 展示"首页"按钮绑定该命令。

#### Scenario: 点击首页跳转到第一页
- **WHEN** 操作员点击"首页"按钮且 `CurrentPage > 1`
- **THEN** `CurrentPage` SHALL 被设为 1
- **AND** `ReloadRecordsAsync` SHALL 被调用
- **AND** 列表 SHALL 显示第 1 页数据

#### Scenario: 已在首页时点击无效果
- **WHEN** 操作员点击"首页"按钮且 `CurrentPage` 已为 1
- **THEN** `ReloadRecordsAsync` SHALL 被调用（刷新当前页数据）
- **AND** `CurrentPage` SHALL 保持为 1

### Requirement: 尾页导航按钮

`UrbanAttendedWeighingViewModel` SHALL 提供 `GoToLastPageCommand`，将 `CurrentPage` 设为 `TotalPages` 并刷新列表。`UrbanAttendedWeighingWindow.axaml` 分页栏 SHALL 展示"尾页"按钮绑定该命令。

#### Scenario: 点击尾页跳转到最后一页
- **WHEN** 操作员点击"尾页"按钮且 `CurrentPage < TotalPages`
- **THEN** `CurrentPage` SHALL 被设为 `TotalPages`
- **AND** `ReloadRecordsAsync` SHALL 被调用
- **AND** 列表 SHALL 显示最后一页数据

#### Scenario: 已在尾页时点击无效果
- **WHEN** 操作员点击"尾页"按钮且 `CurrentPage` 已等于 `TotalPages`
- **THEN** `ReloadRecordsAsync` SHALL 被调用（刷新当前页数据）
- **AND** `CurrentPage` SHALL 保持不变

### Requirement: 页码输入跳转

`UrbanAttendedWeighingViewModel` SHALL 提供 `GoToPageCommand`，接收目标页码参数，验证范围后设置 `CurrentPage` 并刷新列表。`UrbanAttendedWeighingWindow.axaml` 分页栏 SHALL 展示页码输入 TextBox 和"跳转"按钮。

#### Scenario: 输入有效页码并跳转
- **WHEN** 操作员输入有效整数 N（1 ≤ N ≤ TotalPages）并点击"跳转"
- **THEN** `CurrentPage` SHALL 被设为 N
- **AND** `ReloadRecordsAsync` SHALL 被调用
- **AND** 列表 SHALL 显示第 N 页数据

#### Scenario: 输入超出范围的页码
- **WHEN** 操作员输入的值小于 1 或大于 `TotalPages` 并点击"跳转"
- **THEN** 不执行任何导航操作
- **AND** `CurrentPage` SHALL 保持不变

#### Scenario: 输入非数字内容
- **WHEN** 操作员输入非数字文本并点击"跳转"
- **THEN** 不执行任何导航操作
- **AND** `CurrentPage` SHALL 保持不变

### Requirement: 分页栏 UI 布局

`UrbanAttendedWeighingWindow.axaml` 分页栏 SHALL 在现有"上一页"/"下一页"按钮基础上新增"首页"和"尾页"按钮，以及页码输入框和"跳转"按钮。

#### Scenario: 分页栏按钮排列顺序
- **WHEN** 分页栏渲染
- **THEN** 按钮从左到右排列为："首页"、"上一页"、"下一页"、"尾页"
- **AND** "尾页"按钮右侧 SHALL 有页码输入 TextBox 和"跳转" Button
- **AND** 所有按钮 SHALL 使用 `Classes="secondary-button"` 样式
- **AND** 页码信息文本（"共 N 条 第 X / Y 页"）SHALL 保持不变
