## 1. ViewModel: 新增分页导航命令

- [x] 1.1 在 `UrbanAttendedWeighingViewModel` 中实现 `GoToFirstPageCommand` 异步命令：设置 `CurrentPage = 1`，调用 `ReloadRecordsAsync()`
- [x] 1.2 实现 `GoToLastPageCommand` 异步命令：设置 `CurrentPage = TotalPages`，调用 `ReloadRecordsAsync()`
- [x] 1.3 实现 `GoToPageCommand` 异步命令（接收 `int page` 参数）：验证 `1 ≤ page ≤ TotalPages`，设置 `CurrentPage = page`，调用 `ReloadRecordsAsync()`；无效输入静默忽略

## 2. AXAML: 分页栏 UI 增强

- [x] 2.1 在 `UrbanAttendedWeighingWindow.axaml` 分页栏 StackPanel 中，在"上一页"按钮前新增"首页" Button（`Content="首页" Classes="secondary-button" Command="{Binding GoToFirstPageCommand}"`）
- [x] 2.2 在"下一页"按钮后新增"尾页" Button（`Content="尾页" Classes="secondary-button" Command="{Binding GoToLastPageCommand}"`）
- [x] 2.3 在"尾页"按钮后新增页码输入 TextBox（宽度约 40px）和"跳转" Button（`Content="跳转" Classes="secondary-button" Command="{Binding GoToPageCommand}" CommandParameter="{Binding Text, ElementName=PageJumpTextBox}"`）
