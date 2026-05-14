## ADDED Requirements

### Requirement: Dashboard view renders with sample data
`Views/Home/Index.cshtml` SHALL render the LayUI dashboard with ECharts chart area, statistics cards (today count, attendance count, on-duty count, registered count), and recent activity list. All displayed data SHALL come from hardcoded sample values in the view.

#### Scenario: Dashboard page loads successfully
- **WHEN** a user navigates to `/Home/Index`
- **THEN** the page SHALL render with the full LayUI layout including chart, cards, and activity list

#### Scenario: Statistics cards show sample numbers
- **WHEN** the dashboard is displayed
- **THEN** the four statistics cards SHALL show numeric values (e.g., 1, 1, 22, 28)

### Requirement: Project management table renders with LayUI
`Views/Project/Index.cshtml` SHALL render a LayUI data table that loads data via AJAX from `/Project/PageList`. The table SHALL display columns: ProName, BuildLicenseNo, FdBuildLicenseNo, SyncStatus (switch), LastSyncTime, and action buttons (edit, delete).

#### Scenario: Project list table loads data
- **WHEN** the Project/Index page is loaded
- **THEN** the LayUI table SHALL send an AJAX request to `/Project/PageList` and display the returned data

#### Scenario: Add button opens modal form
- **WHEN** the user clicks the add button
- **THEN** a LayUI layer dialog SHALL open with the `Project/Add` view as content

#### Scenario: Edit button opens pre-filled form
- **WHEN** the user clicks edit on a table row
- **THEN** a LayUI layer dialog SHALL open with form fields pre-filled from the row data

### Requirement: Project add/edit form renders correctly
`Views/Project/Add.cshtml` SHALL render a LayUI form with fields: ProName (required), FdBuildLicenseNo (required), BuildLicenseNo (optional). The form SHALL submit via AJAX POST to `/Project/Add`.

#### Scenario: Form renders with expected fields
- **WHEN** the Add view is loaded
- **THEN** it SHALL display input fields for ProName, FdBuildLicenseNo, and BuildLicenseNo

#### Scenario: Form submission returns success
- **WHEN** the form is submitted with valid data
- **THEN** the AJAX POST SHALL receive a JSON response with `success: true`

### Requirement: Sync info table renders with LayUI
`Views/SyncInfo/Index.cshtml` SHALL render a LayUI data table that loads data via AJAX from `/SyncInfo/PageList`. The table SHALL display columns: CarNo, GoodsWeight, SnapTime, ProName, BuildLicenseNo, SyncType (color-coded status), SyncNumber, SyncTime, and action buttons (view images, view logs).

#### Scenario: Sync data table loads data
- **WHEN** the SyncInfo/Index page is loaded
- **THEN** the LayUI table SHALL send an AJAX request to `/SyncInfo/PageList` and display the returned data

#### Scenario: View images button opens carousel
- **WHEN** the user clicks view images on a row
- **THEN** a LayUI layer dialog SHALL open showing the images from `snapImages` field

#### Scenario: View logs button opens log table
- **WHEN** the user clicks view logs on a row
- **THEN** a LayUI layer dialog SHALL open with a nested table showing sync logs from `/SyncInfo/logList`

### Requirement: Shared layout provides navigation
`Views/Shared/_Layout.cshtml` SHALL provide a Bootstrap navbar with links to Home and Privacy pages, a main content area (`@RenderBody()`), and footer.

#### Scenario: Navigation links work
- **WHEN** a user clicks the Home navigation link
- **THEN** the browser SHALL navigate to `/Home/Index`

### Requirement: Static resources are served from wwwroot
LayUI framework files (`wwwroot/public/layui/`) and custom styles (`wwwroot/public/style/`) SHALL be accessible via HTTP. Views SHALL reference these using paths like `/public/layui/css/layui.css`.

#### Scenario: LayUI JavaScript loads
- **WHEN** a view includes `<script src="/public/layui/layui.js">`
- **THEN** the LayUI framework SHALL be loaded and `layui.config()` SHALL execute without errors
