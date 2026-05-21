# Settings UI Specification

## Purpose

定义 MaterialClient.UI 中 SettingsDialog 共享设置框架，包括对话框窗口、ISettingsSection 接口、SettingsViewModel 基类和类型化设置项控件，供主应用和 Urban 应用各自注册设置分区。

## Requirements

### Requirement: SettingsDialog window
MaterialClient.UI MUST provide a `SettingsDialog` window that serves as the shell for all application settings, with a navigation sidebar and a content panel.

#### Scenario: Dialog layout
- **WHEN** SettingsDialog is opened
- **THEN** it SHALL display a title bar with "系统设置" title and a close button
- **AND** SHALL display a left navigation sidebar listing all registered settings sections
- **AND** SHALL display a right content panel showing the selected section's settings
- **AND** SHALL display a "保存设置" button at the bottom of the content panel

#### Scenario: Section navigation
- **WHEN** user clicks a section in the navigation sidebar
- **THEN** the content panel SHALL display that section's settings view
- **AND** the selected navigation item SHALL be visually highlighted
- **AND** the previously selected section's view SHALL be unloaded

#### Scenario: Close dialog without saving
- **WHEN** user clicks the close button or presses Escape
- **THEN** the dialog SHALL close without persisting any changes
- **AND** any in-memory setting modifications SHALL be discarded

### Requirement: ISettingsSection interface
MaterialClient.UI MUST define an `ISettingsSection` interface that each settings section MUST implement to integrate with the SettingsDialog.

#### Scenario: Interface contract
- **WHEN** a class implements ISettingsSection
- **THEN** it SHALL expose a `DisplayName` property (string, shown in navigation)
- **AND** SHALL expose a `CreateView()` method returning an Avalonia `Control`
- **AND** SHALL expose a `LoadAsync(CancellationToken)` method for loading settings
- **AND** SHALL expose a `SaveAsync(CancellationToken)` method for persisting settings
- **AND** SHALL expose an `IsDirty` property (bool, tracks unsaved changes)

#### Scenario: Section registration via ABP convention
- **WHEN** an app defines settings sections
- **THEN** each section SHALL implement ISettingsSection and ITransientDependency
- **AND** SHALL be automatically discovered by the SettingsDialog via ABP service resolution
- **AND** MUST NOT require manual registration in module configuration

### Requirement: SettingsViewModel base class
MaterialClient.UI MUST provide a `SettingsViewModel` base class that manages the sections collection, selected section, and save command orchestration.

#### Scenario: Sections collection initialization
- **WHEN** SettingsViewModel is constructed
- **THEN** it SHALL resolve all ISettingsSection implementations from the DI container
- **AND** SHALL populate the Sections ObservableCollection
- **AND** SHALL set the first section as SelectedSection

#### Scenario: Save all sections
- **WHEN** user clicks "保存设置"
- **THEN** SettingsViewModel SHALL call SaveAsync() on each section that has IsDirty = true
- **AND** SHALL process sections sequentially
- **AND** SHALL report success if all sections save successfully
- **AND** SHALL report failure if any section fails, without rolling back successful saves

#### Scenario: Save command availability
- **WHEN** no sections have IsDirty = true
- **THEN** the save command SHALL be disabled

### Requirement: Typed setting item controls
MaterialClient.UI MUST provide reusable setting item controls for common setting types.

#### Scenario: ToggleSettingItem
- **WHEN** a boolean setting is displayed
- **THEN** it SHALL render as a label + toggle switch
- **AND** the toggle SHALL reflect the current setting value
- **AND** changing the toggle SHALL update the bound value

#### Scenario: DropdownSettingItem
- **WHEN** an enum or list setting is displayed
- **THEN** it SHALL render as a label + ComboBox
- **AND** the ComboBox SHALL list all available options
- **AND** the current selection SHALL reflect the setting value

#### Scenario: SliderSettingItem
- **WHEN** a numeric range setting is displayed
- **THEN** it SHALL render as a label + Slider + value display
- **AND** the slider SHALL respect Min, Max, and Step constraints

#### Scenario: TextSettingItem
- **WHEN** a text setting is displayed
- **THEN** it SHALL render as a label + TextBox
- **AND** the TextBox SHALL display the current setting value

### Requirement: Settings section extensibility
Each consuming app MUST be able to add its own settings sections without modifying the shared SettingsDialog framework.

#### Scenario: Main app sections
- **WHEN** MaterialClient main app registers settings sections
- **THEN** it SHALL include sections for: scale, weighing, camera, LPR, system, sound device, printer
- **AND** each section SHALL implement ISettingsSection + ITransientDependency

#### Scenario: Urban sections
- **WHEN** MaterialClient.Urban registers settings sections
- **THEN** it SHALL include sections relevant to urban weighing (scale, camera, LPR, system)
- **AND** MUST NOT include sections not applicable to urban mode (e.g., printer if not supported)

#### Scenario: No section conflicts
- **WHEN** both apps define sections with the same DisplayName
- **THEN** only the sections registered in the running app's assembly SHALL appear
- **AND** sections from the other app SHALL NOT appear (assembly isolation)
