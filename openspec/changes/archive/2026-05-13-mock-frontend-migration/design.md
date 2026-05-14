## Context

UrbanManagement 当前使用 Bootstrap 5 navbar 布局 + LayUI 组件的混合架构。后端控制器已通过 `ISampleDataProvider` 服务提供 mock 数据，所有 API 端点（PageList、Add、Del、SetStatus、LogList）已返回 mock JSON 响应。

参考项目 FdSoft.MaterialSys.Gov.XiaoShanServe 使用纯 LayUI admin 后台管理布局，架构为：
- `Home/Index` 作为主框架页（LayUI admin layout），内含 iframe 加载子页面
- `MainPage/Index` 作为仪表盘（iframe 首页内容）
- `Project/Index`、`SyncInfo/Index` 作为 iframe 子页面
- 所有子页面 `Layout = null`，独立完整的 HTML 文档

### 当前架构 vs 目标架构

```
当前架构（Bootstrap navbar 导航）:
┌──────────────────────────────────────────┐
│ Bootstrap Navbar: Home|Project|SyncInfo  │
├──────────────────────────────────────────┤
│                                          │
│        @RenderBody() - 单页内容           │
│                                          │
├──────────────────────────────────────────┤
│ Footer                                   │
└──────────────────────────────────────────┘

目标架构（LayUI admin iframe 框架）:
┌──────────────────────────────────────────┐
│ 顶部工具栏: [刷新] [全屏]     [管理员]    │
├──────┬───────────────────────────────────┤
│ 侧边 │ 标签栏: [首页] [项目管理] [同步管理] │
│ 导航 ├───────────────────────────────────┤
│      │                                   │
│ 项目 │     iframe 内容区                  │
│ 管理 │     (MainPage/Project/SyncInfo)    │
│      │                                   │
│ 同步 ├───────────────────────────────────┤
│ 管理 │                                   │
│      │                                   │
│ ©2024│                                   │
├──────┴───────────────────────────────────┤
│ (移动端遮罩层)                             │
└──────────────────────────────────────────┘
```

## Goals / Non-Goals

**Goals:**
- 完全移植参考项目的 LayUI admin 后台管理布局，包括侧边栏、标签页、iframe 内容区
- 保持现有 `ISampleDataProvider` mock 数据服务不变，控制器继续通过该服务返回数据
- 所有子页面使用 `Layout = null`，不依赖 `_Layout.cshtml`
- 仪表盘（MainPage/Index）使用 ECharts 图表 + 统计卡片 + 最新动态，数据硬编码
- 项目管理、同步管理页面的 AJAX 请求继续走现有控制器 API（已是 mock 数据）
- 前端技术栈：LayUI 2.9.21（CDN）+ ECharts 5.5.1（CDN）+ jQuery 3.7.1（CDN）
- 页面文本使用中文（参考项目风格）
- 界面可独立演示，无需数据库

**Non-Goals:**
- 不引入前端构建工具（Webpack、Vite 等）
- 不修改 `ISampleDataProvider` 的 mock 数据内容
- 不新增真实数据库访问层
- 不实现用户认证/登录功能
- 不实现移动端自适应优化（保持参考项目的基本响应式即可）
- 不修改 ABP 模块配置或依赖注入架构
- 不处理 eleTree 插件（参考项目引用但未实际使用该功能）

## Decisions

### Decision 1: LayUI 资源使用 CDN 而非本地文件

**选择**: 继续使用 jsDelivr CDN 引入 LayUI
**替代方案**: 下载 LayUI 到 `wwwroot/public/layui/` 本地部署
**理由**: 当前项目已通过 CDN 成功使用 LayUI 2.9.21 和 ECharts 5.5.1，无需切换到本地文件。参考项目的 `wwwroot/public/layui/` 路径在源码中实际不存在（git 仓库未包含这些文件），其视图引用的是本地部署路径但我们无法获取这些文件。CDN 方案更可靠，且参考项目的视图 URL 路径需从 `/public/layui/` 改为 CDN URL。
**影响**: 视图中所有 LayUI 引用从 `~/public/layui/css/layui.css` 改为 CDN 链接；`layui.config({ base: '/public/' })` 配置需调整为适配 CDN 模式。

### Decision 2: 主框架页作为 Home/Index，新增 MainPageController

**选择**: `Home/Index.cshtml` 改为 LayUI admin 主框架页，新增 `MainPageController` 提供 `/MainPage/Index` 仪表盘
**替代方案 A**: 保留 Home/Index 为仪表盘，新增 `AdminLayoutController` 作为框架页
**替代方案 B**: 使用 `_Layout.cshtml` 实现 admin 框架，通过 section 注入内容
**理由**: 参考项目使用 `Home/Index` 作为框架页 + iframe 加载 `MainPage/Index` 作为首页内容。这是最直接的移植路径，iframe 隔离确保子页面 CSS/JS 不冲突。ABP 默认路由 `{controller=Home}/{action=Index}` 也确保 `/` 直接进入 admin 框架页。
**影响**: `HomeController` 仅保留 `Index()` 方法（返回 admin 框架页）；新增 `MainPageController` 仅有 `Index()` 方法；`_Layout.cshtml` 将不再被 admin 页面使用（仅保留给可能的独立页面）。

### Decision 3: 保留 admin.css 本地文件，补充自定义样式

**选择**: 保留 `wwwroot/public/style/admin.css`，参考参考项目补充缺失的后台管理样式
**理由**: 参考项目在主框架页引用了 `/public/style/admin.css`，当前项目已有该文件但内容不完整。需要补充 LayUI admin 布局所需的核心样式（标签页、侧边栏、footer 等）。
**影响**: 需要从 LayUI admin 官方模板获取必要的 CSS 内容填充 `admin.css`。

### Decision 4: mock 数据策略 - 前端直接调用控制器 API（不使用前端 mock 拦截）

**选择**: 前端页面的 AJAX 请求继续调用现有控制器 API（`/Project/PageList` 等），控制器内部通过 `ISampleDataProvider` 返回 mock 数据
**替代方案**: 前端引入 mock-data.js 拦截 AJAX 请求返回模拟数据
**理由**: 控制器已经完整实现了 mock 数据返回逻辑，无需在前端增加额外的拦截层。这种方式更接近生产环境的数据流，后续替换为真实 API 只需修改控制器实现，前端代码无需变更。
**影响**: 提案中提到的 `wwwroot/js/mock-data.js` 不再需要创建；`ISampleDataProvider` 接口可能需要扩展以支持搜索过滤（当前已支持 `searchText` 参数）。

### Decision 5: 子页面均使用 Layout = null

**选择**: 所有 iframe 子页面（MainPage/Index、Project/Index、Project/Add、SyncInfo/Index）使用 `Layout = null`
**理由**: 参考项目的所有子页面均使用 `Layout = null`，作为独立 HTML 文档在 iframe 中加载。每个子页面自行引入 LayUI CSS/JS，不依赖共享布局。
**影响**: `_Layout.cshtml` 不再被任何页面引用（可保留文件以备后用）。

## Risks / Trade-offs

| 风险 | 缓解措施 |
|------|---------|
| LayUI admin 布局依赖 `layui.config({ base: '/public/' })` 加载内部模块（如 `lib/index`），但本地 `/public/` 下没有这些模块文件 | 使用 CDN 模式时，需要提供 `layui.use()` 的替代模块加载方式；或从 LayUI admin 官方包获取必要模块文件放入 `wwwroot/public/lib/` |
| iframe 方案在移动端体验较差 | 参考项目本身包含基本的移动端适配（遮罩层 + 侧边栏收缩），保持一致即可 |
| 参考项目使用阿里巴巴 iconfont (`at.alicdn.com/t/font_1655180_pexkfcqs6ct.css`)，该 CDN 可能不稳定 | 可使用 LayUI 内置图标替代自定义 iconfont，或下载该字体文件到本地 |
| `admin.css` 内容可能不完整，导致布局显示异常 | 需要从 LayUI admin 官方 GitHub 仓库获取完整的 CSS 文件 |
| 搜索功能仅前端过滤，mock 数据有限可能导致搜索结果不符预期 | mock 数据应包含足够多样化的样本（当前 SampleDataProvider 已有 4 条项目数据） |

## Migration Plan

1. **阶段 1 - 静态资源准备**: 补充 `admin.css` 必要样式；确认 LayUI CDN 引用可用
2. **阶段 2 - 主框架页**: 重写 `Home/Index.cshtml` 为 LayUI admin 框架；新增 `MainPageController` + 仪表盘视图
3. **阶段 3 - 子页面迁移**: 逐个重写 Project/Index、Project/Add、SyncInfo/Index，确保 AJAX 调用指向现有 mock API
4. **阶段 4 - 验证**: 启动应用，检查所有页面路由、表格数据加载、表单操作、模态框功能

**回退策略**: 所有变更在同一个分支进行，如有问题可直接回退到变更前的 commit。

## Open Questions

- LayUI admin 框架页的 `layui.config({ base: '/public/' }).extend({ index: 'lib/index' })` 模块加载：需要确认 `lib/index` 模块的功能是否可以通过 CDN 或简化配置替代
