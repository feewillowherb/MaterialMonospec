## ADDED Requirements

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
