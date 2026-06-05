# Searchable Project Select

## Purpose

定义称重记录页面中可搜索项目下拉选择组件的规范，替换原有的纯文本输入框，支持键盘导航、搜索过滤和 URL 参数预选。

## Requirements

### Requirement: SearchableSelectable project dropdown in WeighingRecord
WeighingRecord.razor SHALL replace the plain text input for project name (`_proName`) with a SearchableSelectable dropdown that loads project names from `IGovProjectAppService.GetListAsync` and supports keyboard-driven search filtering.

#### Scenario: Open dropdown and search
- **WHEN** user clicks the project name dropdown trigger in the WeighingRecord search bar
- **THEN** a dropdown panel SHALL appear listing all available project names, with a search input at the top for filtering

#### Scenario: Select a project from dropdown
- **WHEN** user selects a project name from the dropdown list
- **THEN** the dropdown SHALL close, the selected project name SHALL populate the search filter, and the search SHALL execute automatically

#### Scenario: Clear selected project
- **WHEN** user clears the selected project name via the dropdown clear action
- **THEN** the project filter SHALL be removed and records SHALL reload without project name filtering

#### Scenario: Keyboard navigation within dropdown
- **WHEN** dropdown is open and user presses ArrowDown/ArrowUp keys
- **THEN** focus SHALL move between dropdown items

#### Scenario: Pre-select project from URL query parameter
- **WHEN** user navigates to `/weighing?proName=项目A`
- **THEN** the SearchableSelectable SHALL pre-select "项目A" and automatically trigger a filtered search

### Requirement: Dropdown fetches from existing project list API
The SearchableSelectable component SHALL fetch project names by calling `IGovProjectAppService.GetListAsync` with `MaxResultCount` set to retrieve all projects (no server-side search needed for the dropdown; filtering is client-side).

#### Scenario: Projects load on page initialization
- **WHEN** WeighingRecord page initializes
- **THEN** the SearchableSelectable SHALL fetch and cache the full project list for dropdown rendering

#### Scenario: No projects exist
- **WHEN** no GovProject records exist in the database
- **THEN** the dropdown SHALL show "暂无项目" placeholder text
