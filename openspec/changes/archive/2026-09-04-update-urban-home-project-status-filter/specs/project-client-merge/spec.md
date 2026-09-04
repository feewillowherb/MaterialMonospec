## MODIFIED Requirements

### Requirement: Remove standalone client and device pages
`/clients`, `/clients/{proId}`, and `/device-status` routes SHALL be removed along with ClientList.razor, ClientDetail.razor, and DeviceStatus.razor files. The sidebar primary navigation SHALL treat 项目管理 as the home entry at `/` and MUST NOT include 仪表盘.

#### Scenario: Navigation no longer shows removed pages
- **WHEN** user views the sidebar navigation
- **THEN** "客户端管理" and "设备状态" menu items SHALL NOT appear
- **AND** "仪表盘" menu item SHALL NOT appear
- **AND** "项目管理" SHALL be available as the home route `/`

#### Scenario: Direct URL access to removed pages
- **WHEN** user navigates directly to `/clients` or `/device-status`
- **THEN** the system SHALL redirect to project management home (`/` or `/projects`)

## ADDED Requirements

### Requirement: Status filter uses project-client merge semantics
Project list status filtering SHALL use the same online / offline / unregistered rules as the project table client status column.

#### Scenario: Online filter matches green badge rule
- **WHEN** a project has at least one connected client instance for its `ProId`
- **THEN** it SHALL be included when the online filter is selected
- **AND** SHALL be excluded from offline and unregistered filters

#### Scenario: Unregistered filter matches gray badge rule
- **WHEN** a project has no `ClientOnlineStatus` / client connection rows
- **THEN** it SHALL be included when the unregistered filter is selected
- **AND** SHALL show the gray「未注册」badge when rendered
