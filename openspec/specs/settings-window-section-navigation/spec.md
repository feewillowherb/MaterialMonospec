# Settings Window Section Navigation Specification

## Purpose

定义 MaterialClient.UI `SettingsWindow` 左侧导航驱动右侧「仅当前分区可见」、分区内独立滚动，且不使用 scroll-spy 几何同步。

## Requirements

### Requirement: Settings navigation shows one section at a time

MaterialClient.UI `SettingsWindow` SHALL drive the right-hand content from the left navigation selection so that **only the selected settings section** is shown. Continuous long-page scrolling across all sections MUST NOT be the primary navigation model. Selecting a navigation item SHALL display that section’s controls without requiring manual `ScrollViewer.Offset` / geometry-based scroll targeting in code-behind.

#### Scenario: Select section from navigation

- **WHEN** the operator selects a visible navigation item (e.g. 地磅设置)
- **THEN** the right panel SHALL show that section’s content
- **AND** SHALL NOT require scrolling through other sections to reach it

#### Scenario: Default section on open

- **WHEN** SettingsWindow opens
- **THEN** the client SHALL select a default visible section (地磅设置 when available)
- **AND** SHALL show that section’s content in the right panel

#### Scenario: Hidden Urban-only sections stay out of default

- **WHEN** SettingsWindow opens on a host where Urban-only navigation items are hidden
- **THEN** those items MUST NOT become the selected section
- **AND** the default SHALL remain a host-visible section (e.g. 地磅设置)

### Requirement: Each settings section scrolls independently

Each settings section’s content SHALL scroll inside a height-constrained `ScrollViewer` (or equivalent constrained viewport) belonging to that section. The window layout MUST constrain the content viewport so the `ScrollViewer` can detect overflow (Avalonia: do not place the scrolling viewer in an unconstrained infinite-height parent in the scroll direction).

#### Scenario: Tall section content scrolls within panel

- **WHEN** the selected section’s content exceeds the right panel height
- **THEN** the operator SHALL be able to scroll within that section
- **AND** scrolling MUST NOT reveal other sections’ content

#### Scenario: Short section needs no overflow scroll

- **WHEN** the selected section’s content fits in the right panel
- **THEN** the section MAY show without an active vertical scrollbar
- **AND** other sections MUST remain undisplayed until selected

### Requirement: No scroll-spy navigation sync

SettingsWindow MUST NOT implement bidirectional scroll-spy that updates left navigation selection from right-panel scroll position using section geometry (`TranslatePoint`, scroll scoring, or equivalent). Programmatic jumps to a control SHALL use Avalonia `BringIntoView` (or focus-driven bring-into-view) when needed, not hand-calculated `Offset` maps keyed by fragile `FindControl` dictionaries for every section header.

#### Scenario: Code-behind does not map every section for scroll sync

- **WHEN** a new settings section is added following the supported pattern
- **THEN** maintainers MUST NOT be required to register scroll-anchor dictionaries for scroll-spy
- **AND** navigation SHALL continue to work by selection → section display only

### Requirement: Section visibility is driven by SelectedSettingsSection

MaterialClient.UI `SettingsWindow` SHALL bind each settings section’s visibility to `SettingsWindowViewModel.SelectedSettingsSection` (or equivalent computed flags). Selecting a left navigation item SHALL update that property. The primary path MUST NOT register navigation controls in a `FindControl` dictionary or iterate the section host’s children in code-behind to set `IsVisible`.

#### Scenario: Navigation updates selected section property

- **WHEN** the operator selects a visible navigation item whose tag is `WeighingSettings`
- **THEN** `SelectedSettingsSection` SHALL equal `WeighingSettings`
- **AND** only the weighing section SHALL be visible

#### Scenario: No nav registry for section switching

- **WHEN** a maintainer adds a new settings section following the supported pattern
- **THEN** they SHALL add a navigation item and a section whose visibility binds to the selected section key
- **AND** they MUST NOT be required to register the item in a code-behind name dictionary for switching
