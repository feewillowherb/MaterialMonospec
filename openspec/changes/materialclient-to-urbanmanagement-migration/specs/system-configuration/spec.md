## MODIFIED Requirements

### Requirement: ProductCode query interface
`ISettingsService` SHALL provide a method to query the current `ProductCode` derived from the stored `WeighingMode`.

#### Scenario: Get ProductCode from settings
- **WHEN** `GetProductCodeAsync()` is called
- **THEN** the system SHALL read the current `WeighingMode` from settings
- **AND** SHALL return `ProductCode.Standard` for `WeighingMode.Standard`
- **AND** SHALL return `ProductCode.SolidWaste` for `WeighingMode.SolidWaste`
- **AND** SHALL return `ProductCode.Urban` for `WeighingMode.UrbanMode`
- **AND** SHALL return `ProductCode.Recycle` for `WeighingMode.Recycle`

#### Scenario: Default ProductCode when no settings exist
- **WHEN** `GetProductCodeAsync()` is called and no settings record exists
- **THEN** the system SHALL create default settings
- **AND** SHALL return `ProductCode.Standard`

### Requirement: SaveDefaultWeighingModeAsync supports UrbanMode
`ISettingsService.SaveDefaultWeighingModeAsync` SHALL correctly map `ProductCode.Urban` to `WeighingMode.UrbanMode`.

#### Scenario: Save Urban ProductCode
- **WHEN** `SaveDefaultWeighingModeAsync(ProductCode.Urban)` is called
- **THEN** the system SHALL set `DefaultWeighingMode = WeighingMode.UrbanMode`
- **AND** SHALL persist the settings

#### Scenario: Save Standard ProductCode
- **WHEN** `SaveDefaultWeighingModeAsync(ProductCode.Standard)` is called
- **THEN** the system SHALL set `DefaultWeighingMode = WeighingMode.Standard`

#### Scenario: Save SolidWaste ProductCode
- **WHEN** `SaveDefaultWeighingModeAsync(ProductCode.SolidWaste)` is called
- **THEN** the system SHALL set `DefaultWeighingMode = WeighingMode.SolidWaste`

#### Scenario: Save Recycle ProductCode
- **WHEN** `SaveDefaultWeighingModeAsync(ProductCode.Recycle)` is called
- **THEN** the system SHALL set `DefaultWeighingMode = WeighingMode.Recycle`
- **AND** SHALL persist the settings
