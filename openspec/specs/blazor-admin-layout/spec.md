# Blazor Admin Layout

## Purpose

定义 UrbanManagement Blazor 应用的管理员布局组件，包括侧边栏导航、顶部工具栏、标签页栏和内容区域。该布局组件替代原有的 Layui + iframe 架构，使用纯 Blazor 组件实现多页面标签页管理。

## Requirements

### Requirement: Admin layout sidebar navigation
`AdminLayout.razor` SHALL render a fixed left sidebar with navigation links to all primary pages. The sidebar SHALL display the application title and a copyright footer.

#### Scenario: Sidebar navigation links
- **WHEN** `AdminLayout.razor` renders
- **THEN** the sidebar SHALL contain navigation links for: 仪表盘 (`/`), 项目管理 (`/projects`), 称重记录 (`/weighing`), 客户端管理 (`/clients`), 设备状态 (`/device-status`)
- **AND** the currently active link SHALL have a distinct visual style

#### Scenario: Sidebar structure
- **WHEN** `AdminLayout.razor` renders
- **THEN** the sidebar SHALL display "萧山城管<br>对接平台" as the logo/title area
- **AND** SHALL display "凡东科技" as the footer

### Requirement: Admin layout tab bar
`AdminLayout.razor` SHALL render a horizontal tab bar above the content area that tracks opened pages and allows closing individual tabs.

#### Scenario: Tab opens on navigation
- **WHEN** the user navigates to a page via sidebar link
- **THEN** a new tab SHALL appear in the tab bar with the page title
- **AND** if a tab for that page already exists, the existing tab SHALL become active instead of creating a duplicate

#### Scenario: Tab closes on click
- **WHEN** the user clicks the close button on a tab (not the home tab)
- **THEN** the tab SHALL be removed from the tab bar
- **AND** the previously active tab SHALL become the current view

#### Scenario: Home tab is persistent
- **WHEN** the layout renders
- **THEN** a "首页" tab SHALL always be present and SHALL NOT have a close button

#### Scenario: Tab state reflects current URL
- **WHEN** the user navigates via browser URL bar or back/forward buttons
- **THEN** the tab bar SHALL update to reflect the current route

### Requirement: Admin layout top toolbar
`AdminLayout.razor` SHALL render a fixed top header bar with utility buttons.

#### Scenario: Toolbar buttons
- **WHEN** `AdminLayout.razor` renders
- **THEN** the top bar SHALL contain a refresh button and a fullscreen toggle button
- **AND** SHALL display "管理员" as the user indicator on the right side

### Requirement: Admin layout content area
`AdminLayout.razor` SHALL render a content area using `@Body` for the active Blazor page.

#### Scenario: Content area rendering
- **WHEN** a Blazor page is active
- **THEN** the content area SHALL render the page component at `@Body`
- **AND** the content area SHALL NOT use iframes

### Requirement: Admin layout responsive behavior
`AdminLayout.razor` SHALL support mobile responsive layout.

#### Scenario: Mobile sidebar toggle
- **WHEN** viewport width is below 992px
- **THEN** the sidebar SHALL be hidden by default
- **AND** a toggle button SHALL appear to show/hide the sidebar
- **AND** clicking outside the sidebar SHALL close it

### Requirement: Admin layout CSS compatibility
`AdminLayout.razor` SHALL use the existing `admin.css` styles from `wwwroot/public/style/admin.css`.

#### Scenario: Style preservation
- **WHEN** `AdminLayout.razor` renders
- **THEN** it SHALL use CSS class names compatible with the existing `admin.css` definitions
- **AND** SHALL NOT load the Layui CSS/JS library
