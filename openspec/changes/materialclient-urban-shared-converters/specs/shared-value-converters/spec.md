## ADDED Requirements

### Requirement: Shared value converters in MaterialClient.UI

MaterialClient.UI MUST contain all Avalonia value converters previously located in `MaterialClient/Converters/`, exposed under namespace `MaterialClient.UI.Converters`. The set MUST include at minimum: `BoolToBrushConverter`, `CarNullOrEmptyImageConverter`, `EqualityToColorConverter`, `LprDeviceTypeConverter`, `MaterialUnitDisplayConverter`, `NullableBitmapToImageConverter`, `NullOrEmptyImageConverter`, `ProductCodeConverter`, `ScaleTypeConverter`, `ScaleUnitConverter`, `StreamTypeConverter`, and `WeighingModeConverter`.

#### Scenario: Converters compile in UI library
- **WHEN** MaterialClient.UI project is built
- **THEN** all converter types SHALL compile without referencing MaterialClient or MaterialClient.Urban projects
- **AND** converters MAY reference MaterialClient.Common types and utilities (e.g. `PathManager`)

#### Scenario: Default vehicle image resource
- **WHEN** `CarNullOrEmptyImageConverter` receives null or whitespace path
- **THEN** it SHALL load default image from `avares://MaterialClient.UI/Assets/Car_Default.png`
- **AND** the PNG SHALL be included as AvaloniaResource in MaterialClient.UI

### Requirement: SharedConverters resource dictionary

MaterialClient.UI MUST provide `Styles/SharedConverters.axaml` that registers every shared converter with stable `x:Key` names matching the former MaterialClient App.axaml keys (e.g. `CarNullOrEmptyImageConverter`, `NullOrEmptyImageConverter`).

#### Scenario: Resource dictionary is loadable
- **WHEN** a consuming application includes `avares://MaterialClient.UI/Styles/SharedConverters.axaml` via StyleInclude
- **THEN** `{StaticResource CarNullOrEmptyImageConverter}` SHALL resolve in any window or user control
- **AND** `{StaticResource BoolToBrushConverter}` SHALL resolve without per-window registration

#### Scenario: Both apps consume shared converters
- **WHEN** MaterialClient App.axaml is loaded
- **THEN** it SHALL StyleInclude SharedConverters.axaml
- **AND** SHALL NOT duplicate converter instances in app-local Style.Resources

- **WHEN** MaterialClient.Urban App.axaml is loaded
- **THEN** it SHALL StyleInclude SharedConverters.axaml
- **AND** Urban windows SHALL be able to use the same StaticResource keys as MaterialClient

### Requirement: CarNullOrEmptyImageConverter path resolution

`CarNullOrEmptyImageConverter` MUST resolve local file paths via `PathManager.ToAbsolutePath` and MUST support `avares://` URIs. Paths starting with `/Assets/` MUST resolve against MaterialClient.UI embedded assets after migration.

#### Scenario: Empty path shows default truck image
- **WHEN** bound path is null or empty
- **THEN** converter output SHALL be the default vehicle Bitmap (not null, not emoji TextBlock)

#### Scenario: Valid local file path
- **WHEN** bound path points to an existing file on disk
- **THEN** converter SHALL return Bitmap loaded from that file

#### Scenario: Invalid path falls back to default
- **WHEN** bound path is non-empty but file missing and not a valid avares URI
- **THEN** converter SHALL return the default vehicle Bitmap
