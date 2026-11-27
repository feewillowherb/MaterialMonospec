# admin-vue-workspace Specification

## Purpose
TBD - created by archiving change refactor-admin-vue-shell-and-projects. Update Purpose after archive.
## Requirements
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

### Requirement: Inline two-photo preview column and authenticated attachment image endpoint
The weighing record, weighing approval, checkpoint passage, and finished-product passage pages SHALL remove the legacy `查看照片` action button and standalone photo dialogs, and instead render up to 2 lazy-loaded photo thumbnails side by side in a single `现场照片` column (`InlinePhotoPair`) with click-to-zoom lightbox preview and missing-image placeholders. `UrbanManagement.Admin` SHALL serve attachment images via an authenticated `GET /api/admin/attachments/{id:guid}` endpoint with private caching.

#### Scenario: Operator verifies weighing and passage records inline without opening dialogs
- **WHEN** the operator loads the weighing record, weighing approval, checkpoint passage, or finished-product passage list
- **THEN** each row SHALL render up to 2 lazy-loaded thumbnails from `previewPhotos` URLs in the `现场照片` column
- **AND** clicking a thumbnail SHALL open the lightbox preview allowing switching between the row's images
- **AND** the row actions column SHALL NOT render a `查看照片` button

#### Scenario: Missing or unreadable photo renders graceful placeholder
- **WHEN** a record has fewer than 2 photos or an image returns HTTP `404`
- **THEN** the missing slot SHALL render a muted dashed `无图` placeholder without broken image icons

### Requirement: Weighing record, weighing approval, and passage list views in Vue 3
The Vue 3 Admin workspace SHALL provide `/urban/weighing`, `/urban/weighing-approval`, `/urban/checkpoint-passage`, and `/urban/finished-product-passage` using `OpsDataTable`, `ProjectRemoteSelect`, `DateRangeShortcuts`, and URL Query filter synchronization, while preserving weighing approval editing, photo replacement upload, edit history timeline, and sync reset actions.

#### Scenario: Operator filters by long project name and date shortcuts
- **WHEN** the operator selects a long project name via `ProjectRemoteSelect` or clicks a quick date shortcut (`今日`, `近3天`, `近7天`)
- **THEN** the list SHALL reload with the chosen filters and persist the filter state in the URL query string

#### Scenario: Operator approves an anomalous weighing record
- **WHEN** the operator opens the approval dialog on `/urban/weighing-approval`, edits plate/weight or selects a replacement LPR image, and submits
- **THEN** the backend approval endpoint SHALL be invoked and the table SHALL refresh to reflect the updated status

### Requirement: Client logs and client OTA update pages in Vue 3
The Vue 3 Admin workspace SHALL provide `/ops/client-logs` and `/ops/client-updates` using `OpsDataTable` and authenticated `/api/admin/client-logs/**` and `/api/admin/client-ota/**` BFF endpoints. `/ops/client-logs` SHALL auto-select `?clientId=` when provided, preserve pull result alerts across refreshes, and support remote log querying, pulling by date or selection, cached directory browsing, single/batch ZIP download, and deletion. `/ops/client-updates` SHALL display the server OTA catalog and online 2.0 IPCs with confirmation before triggering updates.

#### Scenario: Operator jumps from project list to client logs with preselected IPC
- **WHEN** the operator navigates to `/ops/client-logs?clientId=<id>`
- **THEN** the matching online IPC SHALL be preselected in the wide IPC selector
- **AND** pull status/error alerts SHALL remain visible until dismissed by the operator

#### Scenario: Operator triggers a selective OTA update
- **WHEN** the operator clicks `推送更新` for an online IPC on `/ops/client-updates` and confirms in the dialog
- **THEN** `POST /api/admin/client-ota/trigger-update` SHALL be called and the result status SHALL be displayed

### Requirement: Root SPA cutover and Blazor Server removal
`UrbanManagement.Admin` SHALL serve the Vue 3 SPA directly at `/` via `MapFallbackToFile("index.html").RequireAuthorization()` while keeping `Login.cshtml` SSO authentication, and SHALL remove Blazor Server hosting, legacy `.razor` UI files, legacy Layui CSS/JS assets, and the Gateway `/_blazor` route.

#### Scenario: Authenticated root path serves Vue 3 SPA without Blazor
- **WHEN** `UrbanManagement.Admin` and `UrbanManagement.Gateway` build and start
- **THEN** `/` and all Admin routes SHALL fall back to `wwwroot/index.html` after cookie authentication
- **AND** no `/_blazor` route or Blazor Server hub SHALL remain registered

