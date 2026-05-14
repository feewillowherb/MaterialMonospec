## Why

当前 UrbanManagement 前端使用 Bootstrap navbar 简单布局，与参考项目 FdSoft.MaterialSys.Gov.XiaoShanServe 的 LayUI admin 后台管理界面风格不一致。需要完整移植参考项目的前端布局体系（LayUI 侧边栏导航 + 标签页 + iframe 内容区），使界面具备专业的后台管理系统外观，同时使用 mock 数据替代所有后端 API，实现前端独立演示。

## What Changes

- **BREAKING** 完全移除当前 `_Layout.cshtml` 的 Bootstrap navbar 布局，替换为 LayUI admin 后台管理布局
- 将 `Views/Home/Index.cshtml` 从当前首页改为 LayUI admin 主框架页面（侧边栏 + 标签页 + iframe），移植参考项目的导航结构和标签页系统
- 新增 `Views/MainPage/Index.cshtml` 仪表盘页面，移植参考项目的 ECharts 图表区、统计卡片（今日数、出勤数、在岗数、在册数）和最新动态列表，使用硬编码 mock 数据
- 重写 `Views/Project/Index.cshtml` 项目管理表格页面，移植 LayUI 数据表格、添加/编辑/删除操作、搜索功能，所有 AJAX 请求使用 mock 数据响应
- 重写 `Views/Project/Add.cshtml` 项目表单页面，保持 LayUI 表单结构，表单提交使用 mock 成功响应
- 重写 `Views/SyncInfo/Index.cshtml` 同步管理表格页面，移植 LayUI 数据表格、状态显示模板、图片查看和日志弹窗功能，使用 mock 数据
- 新增 `wwwroot/public/layui/` LayUI 框架静态资源文件（JS、CSS、字体等）
- 新增 `wwwroot/public/style/admin.css` 后台管理样式文件
- 新增 `wwwroot/public/plugins/eleTree/` 树形组件插件
- 新增 `wwwroot/js/mock-data.js` mock 数据模块，提供所有页面的模拟数据
- 新增 `wwwroot/fd-ico.ico` 应用图标
- 更新 `HomeController` 添加 `MainPage` 相关路由处理（或添加 `MainPageController`）
- 所有 API 端点（`/Project/PageList`、`/Project/Add`、`/Project/Del`、`/Project/SetStatus`、`/SyncInfo/PageList`、`/SyncInfo/logList`）返回 mock 数据

## Capabilities

### New Capabilities
- `mock-data-provider`: Mock 数据提供模块，为所有前端 API 请求返回模拟数据，包括项目列表（含分页）、同步数据列表（含分页）、同步日志、仪表盘统计数据、项目增删改操作的成功/失败响应
- `layui-admin-layout`: LayUI admin 后台管理布局框架，包含侧边栏导航菜单、顶部工具栏（刷新、全屏）、标签页系统、iframe 内容区、移动端响应式适配

### Modified Capabilities
- `view-migration`: 现有视图迁移需求将大幅变更——所有视图从依赖真实后端 API 改为使用 mock 数据；布局从 Bootstrap navbar 改为 LayUI admin 后台管理布局；新增 MainPage 仪表盘视图；侧边栏导航菜单项与参考项目对齐（项目管理、同步管理）

## Impact

- **视图文件**: 所有 `.cshtml` 文件将被重写，Home/Index 改为 admin 框架页，新增 MainPage/Index 仪表盘页
- **控制器**: HomeController 需新增或调整路由；所有控制器 API 方法改为返回 mock 数据
- **静态资源**: `wwwroot/public/` 目录需完整补充 LayUI 框架文件和自定义样式
- **JavaScript**: 新增 `mock-data.js` 模块，各视图内联 JS 的 AJAX 调用需要拦截或重写为使用 mock 数据
- **依赖**: 需要确保 LayUI 2.9.x 框架文件正确部署到 wwwroot；不再依赖 Bootstrap 作为主布局框架（仅保留 Bootstrap 作为备用）
- **路由**: 新增 `/MainPage/Index` 路由；iframe 加载子页面的路由需正确配置
