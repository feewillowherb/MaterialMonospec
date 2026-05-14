## 1. 静态资源准备

- [x] 1.1 补充 `wwwroot/public/style/admin.css`，添加 LayUI admin 布局所需的标签页、侧边栏、页面容器、footer 等核心样式
- [x] 1.2 添加 `wwwroot/fd-ico.ico` 应用图标文件（或使用占位图标）
- [x] 1.3 清理 `wwwroot/public/layui/css/` 和 `wwwroot/public/layui/js/` 空目录（CDN 模式不需要本地 LayUI 文件）

## 2. 控制器调整

- [x] 2.1 新增 `MainPageController`（继承 `AbpController`），提供 `Index()` action 返回 `Views/MainPage/Index.cshtml`
- [x] 2.2 简化 `HomeController`，仅保留 `Index()` action（返回 LayUI admin 框架页），移除 `Privacy()` action

## 3. 主框架页实现

- [x] 3.1 重写 `Views/Home/Index.cshtml` 为 LayUI admin 后台管理框架页（Layout = null），包含：顶部工具栏（刷新、全屏、管理员）、左侧导航菜单（项目管理、同步管理）、标签页系统、iframe 内容区（默认加载 /MainPage/Index）
- [x] 3.2 在主框架页中通过 CDN 引入 LayUI 2.9.21 CSS/JS，引入 `admin.css` 自定义样式
- [x] 3.3 实现 `layui.use()` 初始化逻辑，配置模块加载和标签页管理功能
- [x] 3.4 实现移动端响应式支持（侧边栏收缩、遮罩层）

## 4. 仪表盘页面实现

- [x] 4.1 创建 `Views/MainPage/Index.cshtml` 仪表盘页面（Layout = null），移植参考项目的布局结构：左侧 8 列图表区 + 右侧 4 列统计卡片和最新动态
- [x] 4.2 实现 ECharts 折线图（今日数据），使用硬编码 mock 时序数据
- [x] 4.3 实现四个统计卡片（今日数=1、出勤数=1、在岗数=22、在册数=28），使用 iconfont 图标
- [x] 4.4 实现最新动态列表，显示中文工人进出记录（硬编码 mock 数据）

## 5. 项目管理页面重写

- [x] 5.1 重写 `Views/Project/Index.cshtml`（Layout = null），移植参考项目的 LayUI 数据表格布局：搜索框、添加按钮、数据表格（ProName、BuildLicenseNo、FdBuildLicenseNo、SyncStatus 开关、LastSyncTime、操作列）
- [x] 5.2 实现 LayUI table.render() 配置，AJAX 请求 `/Project/PageList`，包含分页和列定义
- [x] 5.3 实现 SyncStatus 开关模板（lay-skin="switch"），切换时 POST `/Project/SetStatus`
- [x] 5.4 实现操作列模板（编辑、删除按钮），编辑打开 layer iframe 加载 `/Project/Add?proId=X`，删除显示确认弹窗后 POST `/Project/Del`
- [x] 5.5 实现添加按钮功能，打开 layer iframe 加载 `/Project/Add`
- [x] 5.6 实现搜索功能，`form.on("submit(LAY-app-contlist-search)")` 触发 table.reload

## 6. 项目表单页面重写

- [x] 6.1 重写 `Views/Project/Add.cshtml`（Layout = null），移植参考项目的 LayUI 表单结构：ProName（必填）、FdBuildLicenseNo（必填）、BuildLicenseNo（选填）、隐藏提交按钮
- [x] 6.2 实现 `layui.use(['index', 'form'])` 初始化，配置表单验证规则

## 7. 同步管理页面重写

- [x] 7.1 重写 `Views/SyncInfo/Index.cshtml`（Layout = null），移植参考项目的 LayUI 数据表格布局：搜索框、数据表格（CarNo、GoodsWeight、SnapTime、ProName、BuildLicenseNo、SyncType、SyncNumber、SyncTime、操作列）
- [x] 7.2 实现 SyncType 状态模板：红色"同步失败"（SyncType=2）、绿色"同步成功"（SyncType=1）、青色"待同步"（SyncType=0）
- [x] 7.3 实现 SyncNumber 模板：>=10 显示"X次已满"，否则显示次数
- [x] 7.4 实现查看图片功能：layer 弹窗显示 snapImages 中的图片
- [x] 7.5 实现同步日志功能：layer 弹窗内嵌套 LayUI 表格，AJAX 请求 `/SyncInfo/LogList?id=X`
- [x] 7.6 实现搜索和回车搜索功能

## 8. 清理与验证

- [x] 8.1 删除或标记 `_Layout.cshtml` 为不再使用（不删除文件，仅确认无引用）
- [x] 8.2 运行 `dotnet build` 确保项目编译通过
- [x] 8.3 启动应用验证所有页面路由：`/` → admin 框架页、`/MainPage/Index` → 仪表盘、`/Project/Index` → 项目管理、`/SyncInfo/Index` → 同步管理
- [x] 8.4 验证表格数据加载、表单操作、模态框、搜索功能正常工作
