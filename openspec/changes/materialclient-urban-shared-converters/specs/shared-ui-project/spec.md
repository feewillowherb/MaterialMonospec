## MODIFIED Requirements

### Requirement: Shared theme resource dictionary
MaterialClient.UI MUST contain a centralized theme resource dictionary (`SharedTheme.axaml`) that defines all shared color resources, brush resources, and style classes used across MaterialClient and MaterialClient.Urban. MaterialClient.UI MUST also provide `SharedConverters.axaml` for shared Avalonia value converter registration, loadable via the same StyleInclude mechanism as SharedTheme.

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

#### Scenario: Shared converters import
- **WHEN** an app's App.axaml loads
- **THEN** it SHALL import SharedConverters.axaml (in addition to SharedTheme.axaml)
- **AND** `{StaticResource CarNullOrEmptyImageConverter}` SHALL be available application-wide without per-app converter registration blocks

### Requirement: MaterialClient.UI directory structure
MaterialClient.UI MUST follow a consistent directory structure for organizing controls, view models, styles, and abstractions.

#### Scenario: Directory layout
- **WHEN** the MaterialClient.UI project is inspected
- **THEN** it SHALL contain `Controls/` directory for Avalonia controls
- **AND** SHALL contain `ViewModels/` directory for ReactiveUI view models
- **AND** SHALL contain `Styles/` directory for shared theme resources
- **AND** SHALL contain `Abstractions/` directory for interfaces
- **AND** SHALL contain `Models/` directory for data types
- **AND** SHALL contain `Converters/` directory for shared value converters
