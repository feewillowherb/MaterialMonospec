# Blazor Dashboard

## Purpose

定义 UrbanManagement Blazor 应用的仪表盘页面，显示统计卡片、ECharts 图表和最新活动列表。该页面替代原有的 MVC Dashboard 视图，使用纯 Blazor 组件和 ECharts JS interop 实现。

## Requirements

### Requirement: Dashboard statistics cards
`Dashboard.razor` SHALL render summary statistics cards on page load.

#### Scenario: Statistics cards display
- **WHEN** the user navigates to `/` (dashboard)
- **THEN** the page SHALL render 4 statistics cards: 今日数, 出勤数, 在岗数, 在册数
- **AND** each card SHALL display an icon, a label, and a numeric value

### Requirement: Dashboard ECharts line chart
`Dashboard.razor` SHALL render a line chart using ECharts via JS interop.

#### Scenario: Chart initialization
- **WHEN** the dashboard page renders
- **THEN** the page SHALL call JavaScript interop to initialize an ECharts line chart in a designated DOM element
- **AND** the chart SHALL display with X-axis time labels and a smooth area line series

#### Scenario: Chart responsive resize
- **WHEN** the browser window is resized
- **THEN** the ECharts chart SHALL resize to fit the container

#### Scenario: Chart cleanup on dispose
- **WHEN** the user navigates away from the dashboard
- **THEN** the ECharts instance SHALL be disposed via `IAsyncDisposable` to prevent memory leaks

### Requirement: Dashboard latest activity feed
`Dashboard.razor` SHALL render a list of recent activity entries.

#### Scenario: Activity feed display
- **WHEN** the dashboard page renders
- **THEN** the page SHALL render a scrollable list of recent activity entries
- **AND** each entry SHALL display a description and a relative timestamp

### Requirement: Dashboard no external JS framework dependency
`Dashboard.razor` SHALL only use ECharts via minimal JS interop and MUST NOT depend on Layui or jQuery.

#### Scenario: No Layui/jQuery on dashboard
- **WHEN** the dashboard page renders
- **THEN** the page MUST NOT reference `layui.js`, `layui.css`, or `jquery.js` from any CDN
