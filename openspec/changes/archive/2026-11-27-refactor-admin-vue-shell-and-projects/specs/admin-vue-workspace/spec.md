## ADDED Requirements

### Requirement: Admin Vue 3 workspace shell and 3-group root navigation
The Admin web application SHALL provide a Vue 3 + Element Plus workspace shell with a collapsible dark sidebar organized into three top-level root navigation groups: `城管` (5001), `资源化` (5020), and `工控机运维` (shared). It SHALL display `工控运维管理平台` as the platform title, provide a top bar with breadcrumb, refresh, current account, and logout controls, update `document.title` on route change, and SHALL NOT include `/recycle/device-status` or a legacy multi-tab bar.

#### Scenario: Root navigation separates Urban, Recycle, and shared IPC operations
- **WHEN** an authenticated operator opens the Vue Admin workspace
- **THEN** the sidebar SHALL render three distinct root groups: `城管` (城管项目, 称重记录, 卡口进出, 成品进出, 异常审批), `资源化` (资源化项目), and `工控机运维` (客户端日志, 客户端更新)
- **AND** `document.title` SHALL reflect the active page title

#### Scenario: Unauthenticated API request redirects to login
- **WHEN** the Vue Admin frontend receives HTTP `401` from any `/api/**` endpoint
- **THEN** it SHALL redirect the browser to `/login` with the current path preserved as `returnUrl`

### Requirement: Scrollable resizable data table component
All data tables in the Vue Admin workspace SHALL render inside a bounded scrollable container with sticky headers and user-resizable column headers, persisting column widths per table in `localStorage` with a reset action.

#### Scenario: Operator drags a column header to resize
- **WHEN** the operator drags the border of any table header column
- **THEN** the column width SHALL update immediately without breaking table alignment
- **AND** the updated width SHALL be persisted in `localStorage` and restored on reload until reset

### Requirement: Wide multi-line project search selector
The shared project search selector (`ProjectRemoteSelect`) SHALL render its dropdown popper wider than the narrow trigger input and wrap long project names across multiple lines without single-line truncation, supporting fuzzy search by project name or access code.

#### Scenario: Operator searches among long similar project names
- **WHEN** the operator opens the project selector and types a keyword
- **THEN** the dropdown popper SHALL display full project names wrapped across lines alongside their access codes so visually similar prefixes remain distinguishable

### Requirement: Project management list with multi-IPC redundancy and inline LPR status
The Urban (`5001`) and Recycle (`5020`) project management pages SHALL label the client status column as `工控机`, narrow the default width of `项目地址`, format `授权过期时间` as `yyyy-MM-dd`, remove the `设备` action button and device detail modal, display `抓拍机` (LPR) status directly in the table while discarding scale and camera UI indicators, and support multiple IPCs under a single project/access code via aggregated status badges and an expandable IPC sub-table.

#### Scenario: Single-IPC and multi-IPC projects render accurately
- **WHEN** the operator views the project management list
- **THEN** single-IPC projects SHALL display `在线`, `离线`, or `未注册` in the `工控机` column and `在线`, `离线`, `在线 X/Y`, `异常 X/Y`, or `未上报` in the `抓拍机` column
- **AND** multi-IPC projects SHALL display aggregated counts (such as `在线 2/2` or `异常 1/2`) and allow expanding a sub-table listing each IPC's identifier, status, LPR status, app version, last online time, and per-IPC log/update navigation

#### Scenario: Project address, authorization date, and actions match streamlined spec
- **WHEN** the project management table renders
- **THEN** `授权过期时间` SHALL be formatted as `yyyy-MM-dd` (or `-` when absent)
- **AND** the actions column SHALL NOT render a `设备` button
- **AND** `项目地址` SHALL use a compact default width with full-text tooltip on hover

### Requirement: Authenticated Admin BFF endpoints for session, project status summary, logs, and OTA
`UrbanManagement.Admin` SHALL expose authenticated BFF endpoints under `/api/session`, `/api/admin/projects/status-summary`, `/api/admin/client-logs/**`, and `/api/admin/client-ota/**` protected by `UrbanAdmin.Session` cookie authentication.

#### Scenario: Project status summary aggregates IPCs and LPR only
- **WHEN** an authenticated client calls `GET /api/admin/projects/status-summary`
- **THEN** the response SHALL return project-keyed summaries containing IPC counts, aggregated IPC status, aggregated LPR status, last online time, and per-IPC details (`Ipcs`)
- **AND** non-LPR device types (`Scale`, `Camera`) SHALL NOT be included in the LPR aggregation
