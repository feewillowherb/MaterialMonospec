## 1. CSS 样式准备

- [x] 1.1 在 `repos/UrbanManagement/src/UrbanManagement.App/wwwroot/css/components.css` 中新增 `.searchable-select` 下拉组件样式：trigger 按钮、dropdown 面板、搜索输入、列表项高亮与 hover 状态、keyboard focus indicator
- [x] 1.2 在 `repos/UrbanManagement/src/UrbanManagement.App/wwwroot/css/components.css` 中新增设备详情 Modal 所需的 `.device-modal` 覆盖样式（确保 modal 内 device-detail-grid 间距正确）
- [x] 1.3 从 `repos/UrbanManagement/src/UrbanManagement.App/wwwroot/public/style/admin.css` 中移除 `.client-card`、`.client-header`、`.client-name`、`.connection-status`、`.no-devices`、`.device-grid`、`.device-card`、`.device-type`、`.device-status`、`.device-time`、`.device-status-page`、`.loading-message`、`.empty-title`、`.empty-hint`、`.connection-indicator` 等仅 DeviceStatus 使用的样式

## 2. 删除独立客户端与设备页面

- [x] 2.1 删除 `repos/UrbanManagement/src/UrbanManagement.App/Pages/ClientList.razor` 文件
- [x] 2.2 删除 `repos/UrbanManagement/src/UrbanManagement.App/Pages/ClientDetail.razor` 文件
- [x] 2.3 删除 `repos/UrbanManagement/src/UrbanManagement.App/Pages/DeviceStatus.razor` 文件

## 3. 导航菜单精简

- [x] 3.1 修改 `repos/UrbanManagement/src/UrbanManagement.App/Pages/AdminLayout.razor` 中的 `_navItems` 列表，移除 `/clients`（客户端管理）和 `/device-status`（设备状态）两个 NavItem，保留仪表盘、项目管理、称重记录三项

## 4. ProjectManagement 页面重写

- [ ] 4.1 添加 `@using Microsoft.AspNetCore.SignalR.Client`、`@inject IDeviceStatusAppService`、`@inject NavigationManager`、`@implements IAsyncDisposable` 指令
- [ ] 4.2 新增 `_clients` 状态字段（`List<ClientConnectionDto>`），在 `OnInitializedAsync` 中并行调用 `GovProjectAppService.GetListAsync` 和 `DeviceStatusAppService.GetClientListAsync`
- [ ] 4.3 实现项目与客户端状态的合并逻辑：遍历 `_projects`，通过 `GovProject.FdBuildLicenseNo` 匹配 `ClientConnectionDto.ProId`，生成 per-row 的连接状态（在线/离线/未注册）
- [ ] 4.4 在项目表格中新增「客户端」列，使用 `badge-online` / `badge-offline` / `badge-muted` 展示连接状态
- [ ] 4.5 在项目表格操作列新增「设备」按钮，点击时调用 `GetClientDevicesAsync(proId)` 并弹出设备详情 Modal（复用 ClientDetail 的 device-detail-grid 卡片布局、设备图标映射、状态 badge 映射）
- [ ] 4.6 实现设备详情 Modal 的 HTML 结构和交互逻辑（打开/关闭、加载状态、Escape 关闭）
- [ ] 4.7 在项目表格操作列新增「称重」按钮，点击时 `NavigationManager.NavigateTo($"/weighing?proName={Uri.EscapeDataString(project.ProName)}")`
- [ ] 4.8 迁移 SignalR 连接管理：初始化 HubConnection 连接 `/hubs/devicestatus`，订阅 `ClientConnectionUpdate` 事件刷新客户端列表；实现 `Reconnecting`/`Reconnected`/`Closed` 状态处理
- [ ] 4.9 迁移 fallback polling：当 SignalR 未连接时每 30 秒轮询 `GetClientListAsync`
- [ ] 4.10 实现 `DisposeAsync`：取消 polling CancellationTokenSource、dispose HubConnection

## 5. WeighingRecord 页面修改

- [ ] 5.1 添加 `@inject IGovProjectAppService GovProjectAppService` 和 `@inject NavigationManager NavigationManager` 指令
- [ ] 5.2 新增 `_allProjects` 缓存字段（`List<GovProjectDto>`），在 `OnInitializedAsync` 中调用 `GovProjectAppService.GetListAsync`（MaxResultCount=1000）加载全部项目列表
- [ ] 5.3 将项目名称 `<input>` 替换为 SearchableSelect trigger 按钮（显示当前选中项目名或 placeholder "选择项目"）
- [ ] 5.4 实现 SearchableSelect dropdown 面板：搜索输入框 + 项目列表（支持客户端过滤），点击选中后关闭 dropdown 并触发搜索
- [ ] 5.5 实现 dropdown 的打开/关闭逻辑：点击 trigger toggle，点击外部关闭，Escape 关闭
- [ ] 5.6 实现键盘导航：ArrowDown/ArrowUp 在列表项间移动，Enter 选中，Escape 关闭
- [ ] 5.7 实现 `OnParametersAsync` 或 `OnInitializedAsync` 中从 `NavigationManager` 解析 `proName` query parameter，自动预选项目并触发搜索
- [ ] 5.8 在 SearchableSelect trigger 上显示清除按钮（已有选中项目时），点击清除项目过滤并刷新列表

## 6. 验证

- [ ] 6.1 确认 ProjectManagement 页面加载后正确显示项目列表及每行的客户端在线状态
- [ ] 6.2 确认设备详情 Modal 弹出后显示正确的设备卡片和状态
- [ ] 6.3 确认 SignalR 连接状态栏正常显示，客户端上下线时状态实时更新
- [ ] 6.4 确认点击「称重」按钮后跳转到 WeighingRecord 页面且项目名称已预选
- [ ] 6.5 确认 WeighingRecord 的 SearchableSelect 下拉正常工作（搜索过滤、选中、清除）
- [ ] 6.6 确认侧边栏只显示 3 个导航项，`/clients` 和 `/device-status` 路由不可访问
