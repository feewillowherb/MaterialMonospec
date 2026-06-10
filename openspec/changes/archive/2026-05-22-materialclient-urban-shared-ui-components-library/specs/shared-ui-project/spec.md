## ADDED Requirements

### Requirement: MaterialClient.UI Avalonia class library project
MaterialClient.UI MUST be a buildable Avalonia class library project targeting `net10.0`, included in the MaterialClient solution file.

#### Scenario: Project builds successfully
- **WHEN** the solution is built
- **THEN** MaterialClient.UI project SHALL compile without errors
- **AND** the output assembly SHALL be `MaterialClient.UI.dll`

#### Scenario: Project references are correct
- **WHEN** MaterialClient.UI.csproj is inspected
- **THEN** it SHALL reference `MaterialClient.Common` via ProjectReference
- **AND** it SHALL reference `Avalonia` package
- **AND** it SHALL reference `ReactiveUI` packages (ReactiveUI, ReactiveUI.Fody or SourceGenerators)
- **AND** it MUST NOT reference app-specific projects (MaterialClient, MaterialClient.Urban)

#### Scenario: Solution integration
- **WHEN** MaterialClient.sln is loaded
- **THEN** MaterialClient.UI project SHALL be listed
- **AND** both MaterialClient and MaterialClient.Urban SHALL have ProjectReference to MaterialClient.UI

#### Scenario: Build configuration inheritance
- **WHEN** MaterialClient.UI project is built
- **THEN** it SHALL inherit `Directory.Build.props` settings (net10.0, Nullable, ImplicitUsings)
- **AND** it SHALL enable `AvaloniaUseCompiledBindingsByDefault`
- **AND** it SHALL enable `EnableAvaloniaXamlCompilation`

### Requirement: Shared theme resource dictionary
MaterialClient.UI MUST contain a centralized theme resource dictionary (`SharedTheme.axaml`) that defines all shared color resources, brush resources, and style classes used across MaterialClient and MaterialClient.Urban.

#### Scenario: Named color resources
- **WHEN** SharedTheme.axaml is loaded
- **THEN** it SHALL define `PrimaryBlue` (#4169E1)
- **AND** SHALL define `LightBlue` (#4A85F9)
- **AND** SHALL define `BackgroundGray` (#F5F5F5)
- **AND** SHALL define `SuccessGreen` (for online indicators)
- **AND** SHALL define `ErrorRed` (for offline indicators)

#### Scenario: Shared button style classes
- **WHEN** a consuming app imports SharedTheme.axaml
- **THEN** `primary-button` style class SHALL be available
- **AND** `titlebar-close-button` style class SHALL be available
- **AND** `titlebar-minimize-button` style class SHALL be available
- **AND** `tab-button` style class SHALL be available
- **AND** each button style SHALL define both normal and disabled states

#### Scenario: Shared border and card styles
- **WHEN** a consuming app imports SharedTheme.axaml
- **THEN** `card-border` style class SHALL be available
- **AND** `section-border` style class SHALL be available

#### Scenario: App-level import
- **WHEN** an app's App.axaml loads
- **THEN** it SHALL import SharedTheme.axaml as a merged resource dictionary
- **AND** the app MAY override specific resources after the import

### Requirement: MaterialClient.UI directory structure
MaterialClient.UI MUST follow a consistent directory structure for organizing controls, view models, styles, and abstractions.

#### Scenario: Directory layout
- **WHEN** the MaterialClient.UI project is inspected
- **THEN** it SHALL contain `Controls/` directory for Avalonia controls
- **AND** SHALL contain `ViewModels/` directory for ReactiveUI view models
- **AND** SHALL contain `Styles/` directory for shared theme resources
- **AND** SHALL contain `Abstractions/` directory for interfaces
- **AND** SHALL contain `Models/` directory for data types
