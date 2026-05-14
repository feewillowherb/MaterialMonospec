# View Migration

## Purpose

Defines the frontend views, LayUI integration, and static resource serving for the UrbanManagement web application, migrated from the original ASP.NET Core views.

## Requirements

### Requirement: Dashboard view renders with sample data
`Views/MainPage/Index.cshtml`（从 `Views/Home/Index.cshtml` 迁移）SHALL 渲染 LayUI 仪表盘页面，包含 ECharts 图表区、统计卡片（今日数、出勤数、在岗数、在册数）和最新动态列表。页面使用 `Layout = null`，通过 iframe 在主框架页内加载。所有数据使用硬编码 mock 值。页面标题和内容 SHALL 使用中文文本。

#### Scenario: Dashboard page loads successfully
- **WHEN** 主框架页的 iframe 加载 `/MainPage/Index`
- **THEN** 页面 SHALL 渲染完整的 LayUI 仪表盘，包含 ECharts 图表、四个统计卡片、最新动态列表

#### Scenario: Statistics cards show sample numbers
- **WHEN** the dashboard is displayed
- **THEN** the four statistics cards SHALL show numeric values (e.g., 1, 1, 22, 28)

#### Scenario: ECharts 图表渲染
- **WHEN** 仪表盘页面加载完成
- **THEN** ECharts SHALL 渲染一个折线图，显示按时统计的数据趋势

#### Scenario: 最新动态列表显示中文内容
- **WHEN** 仪表盘页面加载完成
- **THEN** 最新动态列表 SHALL 显示中文工人进出记录（如"黄杰(凡东科技考勤组)进门"）和时间描述

### Requirement: Project management table renders with LayUI
`Views/Project/Index.cshtml` SHALL 渲染 LayUI 数据表格页面，使用 `Layout = null`，通过 iframe 加载。表格通过 AJAX 从 `/Project/PageList` 加载 mock 数据。显示列：ProName、BuildLicenseNo、FdBuildLicenseNo、SyncStatus（开关切换）、LastSyncTime、操作按钮（编辑、删除）。页面包含搜索框和添加按钮。

#### Scenario: Project list table loads data
- **WHEN** the Project/Index page is loaded
- **THEN** the LayUI table SHALL send an AJAX request to `/Project/PageList` and display the returned mock data

#### Scenario: Add button opens modal form
- **WHEN** the user clicks the add button
- **THEN** a LayUI layer dialog SHALL open with the `Project/Add` view as iframe content

#### Scenario: Edit button opens pre-filled form
- **WHEN** the user clicks edit on a table row
- **THEN** a LayUI layer dialog SHALL open with the `Project/Add` view as iframe content, form fields pre-filled from the row data

#### Scenario: Delete button shows confirmation
- **WHEN** the user clicks delete on a table row
- **THEN** a LayUI confirm dialog SHALL appear asking "确定删除此项目？"
- **AND** 确认后 SHALL 发送 POST 请求到 `/Project/Del` 并刷新表格

#### Scenario: SyncStatus 开关切换
- **WHEN** the user clicks the SyncStatus switch on a table row
- **THEN** a POST request SHALL be sent to `/Project/SetStatus` with the row's ProId

#### Scenario: 搜索功能过滤数据
- **WHEN** the user types in the search box and submits
- **THEN** the table SHALL reload with filtered results via `table.reload()` with the search parameter

### Requirement: Project add/edit form renders correctly
`Views/Project/Add.cshtml` SHALL 渲染 LayUI 表单页面，使用 `Layout = null`。表单字段：ProName（必填）、FdBuildLicenseNo（必填）、BuildLicenseNo（选填）。表单通过 AJAX POST 提交到 `/Project/Add`。

#### Scenario: Form renders with expected fields
- **WHEN** the Add view is loaded
- **THEN** it SHALL display input fields for ProName, FdBuildLicenseNo, and BuildLicenseNo

#### Scenario: Form submission returns success
- **WHEN** the form is submitted with valid data
- **THEN** the AJAX POST SHALL receive a JSON response with `success: true`

### Requirement: Sync info table renders with LayUI
`Views/SyncInfo/Index.cshtml` SHALL 渲染 LayUI 数据表格页面，使用 `Layout = null`，通过 iframe 加载。表格通过 AJAX 从 `/SyncInfo/PageList` 加载 mock 数据。显示列：CarNo、GoodsWeight、SnapTime、ProName、BuildLicenseNo、SyncType（颜色编码状态模板）、SyncNumber、SyncTime、操作按钮（查看图片、同步日志）。页面包含搜索框。

#### Scenario: Sync data table loads data
- **WHEN** the SyncInfo/Index page is loaded
- **THEN** the LayUI table SHALL send an AJAX request to `/SyncInfo/PageList` and display the returned mock data

#### Scenario: SyncType 状态颜色显示
- **WHEN** 同步数据表格渲染完成
- **THEN** SyncType=2 SHALL 显示红色"同步失败"，SyncType=1 SHALL 显示绿色"同步成功"，SyncType=0 SHALL 显示青色"待同步"

#### Scenario: SyncNumber 超过10次显示提示
- **WHEN** 同步数据的 SyncNumber >= 10
- **THEN** SHALL 显示"X次已满"文本

#### Scenario: View images button opens layer
- **WHEN** the user clicks view images on a row
- **THEN** a LayUI layer dialog SHALL open showing images from the `snapImages` field

#### Scenario: View logs button opens log table
- **WHEN** the user clicks view logs on a row
- **THEN** a LayUI layer dialog SHALL open with a nested table showing sync logs from `/SyncInfo/LogList`

#### Scenario: 搜索功能过滤同步数据
- **WHEN** the user types in the search box and submits
- **THEN** the table SHALL reload with filtered results

### Requirement: Static resources are served from wwwroot
LayUI framework files (`wwwroot/public/layui/`) and custom styles (`wwwroot/public/style/`) SHALL be accessible via HTTP. Views SHALL reference these using paths like `/public/layui/css/layui.css`.

#### Scenario: LayUI JavaScript loads
- **WHEN** a view includes `<script src="/public/layui/layui.js">`
- **THEN** the LayUI framework SHALL be loaded and `layui.config()` SHALL execute without errors

### Requirement: 所有子页面使用独立 HTML 文档结构
所有 iframe 子页面（MainPage/Index、Project/Index、Project/Add、SyncInfo/Index）SHALL 使用 `Layout = null`，作为独立完整的 HTML 文档渲染，各自引入所需的 CSS 和 JS 资源。

#### Scenario: 子页面无共享布局依赖
- **WHEN** 任何子页面的 razor 视图被编译
- **THEN** `Layout` 属性 SHALL 为 `null`，页面包含完整的 `<html>`、`<head>`、`<body>` 结构

#### Scenario: 子页面独立引入 LayUI 资源
- **WHEN** 子页面在 iframe 中加载
- **THEN** 页面 SHALL 通过 CDN 独立引入 LayUI CSS 和 JS，不依赖父框架页的资源

### Requirement: 页面文本使用中文
所有用户可见的页面文本（标题、按钮、表头、提示信息）SHALL 使用中文，与参考项目保持一致。

#### Scenario: 项目管理页面中文显示
- **WHEN** 项目管理页面加载
- **THEN** 页面标题 SHALL 为"项目管理"，按钮文本 SHALL 为"添加"、"编辑"、"删除"，搜索框占位文本 SHALL 为"项目名称，对接码"

#### Scenario: 同步管理页面中文显示
- **WHEN** 同步管理页面加载
- **THEN** 表格列标题 SHALL 为中文（车牌号、重量（千克）、抓拍时间、项目名、项目对接码、同步状态、同步次数、同步时间、操作）

#### Scenario: 主框架页中文显示
- **WHEN** 主框架页加载
- **THEN** 侧边栏标题 SHALL 为"萧山城管对接平台"，菜单项 SHALL 为"项目管理"和"同步管理"，标签页首页 SHALL 为"首页"
