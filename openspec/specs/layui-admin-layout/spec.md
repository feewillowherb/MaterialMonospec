# Layui Admin Layout

## Purpose

Defines the LayUI admin framework layout for the UrbanManagement web application, providing the main shell with navigation, tab system, and iframe-based content loading.

## Requirements

### Requirement: 主框架页提供 LayUI admin 后台管理布局
`Views/Home/Index.cshtml` SHALL 渲染 LayUI admin 后台管理布局框架，包含顶部工具栏、左侧导航菜单、标签页系统、iframe 内容区。页面 `Layout` 设为 `null`。

```
┌──────────────────────────────────────────────────┐
│ 顶部工具栏: [刷新] [全屏]              [管理员]    │
├───────┬──────────────────────────────────────────┤
│  LOGO │ 标签栏: [🏠首页] [项目管理] [同步管理]     │
│ 萧山城 ├──────────────────────────────────────────┤
│ 管对接 │                                          │
│ 平台  │        iframe 内容区                       │
│       │        (默认加载 /MainPage/Index)          │
│ ───── │                                          │
│ 建筑  │                                          │
│ 项目  │                                          │
│ 管理  │                                          │
│ ───── │                                          │
│ 柱状  │                                          │
│ 图同  │                                          │
│ 步管  │                                          │
│ 理   │                                          │
│       │                                          │
│ ©凡东 │                                          │
│ 科技  │                                          │
├───────┴──────────────────────────────────────────┤
│ (移动端遮罩层)                                     │
└──────────────────────────────────────────────────┘
```

#### Scenario: 主框架页加载成功
- **WHEN** 用户访问 `/Home/Index` 或 `/`
- **THEN** 页面 SHALL 渲染完整的 LayUI admin 布局，包含顶部工具栏、侧边栏、标签页、iframe

#### Scenario: 侧边栏显示导航菜单
- **WHEN** 主框架页加载完成
- **THEN** 侧边栏 SHALL 显示两个导航项：「项目管理」（图标: 建筑，链接: /Project/Index）和「同步管理」（图标: 柱状图，链接: /SyncInfo/Index）

#### Scenario: 点击导航菜单加载对应 iframe
- **WHEN** 用户点击侧边栏「项目管理」菜单项
- **THEN** 系统 SHALL 在标签页区域新增「项目管理」标签，iframe 加载 `/Project/Index` 页面

#### Scenario: 首页标签默认显示仪表盘
- **WHEN** 主框架页首次加载
- **THEN** 首页标签 SHALL 处于激活状态，iframe 默认加载 `/MainPage/Index`

#### Scenario: 标签页支持关闭操作
- **WHEN** 用户右键点击非首页标签
- **THEN** 系统 SHALL 提供关闭当前标签、关闭其他标签、关闭全部标签的菜单选项

#### Scenario: 顶部工具栏刷新按钮
- **WHEN** 用户点击顶部刷新按钮
- **THEN** 当前激活的 iframe 页面 SHALL 重新加载

#### Scenario: 顶部工具栏全屏按钮
- **WHEN** 用户点击顶部全屏按钮
- **THEN** 浏览器 SHALL 进入全屏模式

### Requirement: 主框架页使用 CDN 引入 LayUI
主框架页 SHALL 通过 CDN 引入 LayUI 2.9.x 框架（`https://cdn.jsdelivr.net/npm/layui@2.9.21/dist/`），不依赖本地 `/public/layui/` 目录。

#### Scenario: LayUI 从 CDN 加载
- **WHEN** 主框架页加载
- **THEN** LayUI CSS SHALL 从 `https://cdn.jsdelivr.net/npm/layui@2.9.21/dist/css/layui.css` 加载
- **AND** LayUI JS SHALL 从 `https://cdn.jsdelivr.net/npm/layui@2.9.21/dist/layui.js` 加载

### Requirement: admin.css 提供后台管理自定义样式
`wwwroot/public/style/admin.css` SHALL 包含 LayUI admin 布局所需的自定义样式，包括标签页样式、侧边栏样式、页面容器样式。

#### Scenario: admin.css 正确加载
- **WHEN** 主框架页加载
- **THEN** `/public/style/admin.css` SHALL 被成功加载且无 404 错误

#### Scenario: 标签页样式正确渲染
- **WHEN** 主框架页渲染完成
- **THEN** 标签页区域 SHALL 显示正确的样式（标签可点击、激活状态高亮、关闭按钮可见）

### Requirement: 移动端基本响应式支持
主框架页 SHALL 在窄屏设备下提供侧边栏收缩功能，通过遮罩层控制侧边栏的显示/隐藏。

#### Scenario: 窄屏设备侧边栏收缩
- **WHEN** 页面宽度小于 992px
- **THEN** 侧边栏 SHALL 默认隐藏，底部显示收缩控制按钮

#### Scenario: 点击遮罩关闭侧边栏
- **WHEN** 侧边栏在移动端展开且用户点击遮罩层
- **THEN** 侧边栏 SHALL 收回隐藏状态

### Requirement: MainPageController 提供仪表盘路由
`MainPageController` SHALL 继承 `AbpController`，提供 `/MainPage/Index` 路由返回仪表盘视图。

#### Scenario: MainPage 路由可访问
- **WHEN** 用户访问 `/MainPage/Index`
- **THEN** 控制器 SHALL 返回 `Views/MainPage/Index.cshtml` 视图
