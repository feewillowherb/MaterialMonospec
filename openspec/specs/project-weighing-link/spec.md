# Project Weighing Link

## Purpose

定义从项目管理页面导航到称重记录页面的交互规范，支持通过项目行操作按钮快速跳转并预选项目名称。

## Requirements

### Requirement: View weighing records action on project row
Each project row in ProjectManagement.razor SHALL display a "称重" button that navigates to the WeighingRecord page with the project name pre-selected via URL query parameter.

#### Scenario: Click weighing records button
- **WHEN** user clicks the "称重" button on a project row for project "项目A"
- **THEN** the system SHALL navigate to `/weighing?proName=项目A`

#### Scenario: WeighingRecord receives pre-selected project
- **WHEN** the WeighingRecord page loads with `proName` query parameter
- **THEN** the SearchableSelectable SHALL pre-select the matching project and the record list SHALL be filtered by that project name

### Requirement: Navigation preserves tab context
The navigation from ProjectManagement to WeighingRecord SHALL use the existing tab system in AdminLayout.razor — WeighingRecord SHALL open in a new tab if not already open, or switch to the existing tab if it is.

#### Scenario: WeighingRecord tab already open
- **WHEN** user clicks "称重" and a WeighingRecord tab already exists
- **THEN** the system SHALL switch to the existing WeighingRecord tab with the new query parameter applied
