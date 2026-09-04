## MODIFIED Requirements

### Requirement: Admin layout sidebar navigation
`AdminLayout.razor` SHALL render a fixed left sidebar with navigation links to all primary pages. The sidebar SHALL display the application title and a copyright footer.

#### Scenario: Sidebar navigation links
- **WHEN** `AdminLayout.razor` renders
- **THEN** the sidebar SHALL contain navigation links for: 项目管理 (`/`), 称重记录 (`/weighing`), and other primary app pages already present in the layout
- **AND** MUST NOT contain a「仪表盘」navigation link
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
- **THEN** a home tab for `/` SHALL always be present and SHALL NOT have a close button
- **AND** the home tab title SHALL represent project management（「项目管理」或「首页」指向项目管理）

#### Scenario: Tab state reflects current URL
- **WHEN** the user navigates via browser URL bar or back/forward buttons
- **THEN** the tab bar SHALL update to reflect the current route
