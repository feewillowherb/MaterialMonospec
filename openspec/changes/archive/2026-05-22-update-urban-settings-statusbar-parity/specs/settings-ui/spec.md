## MODIFIED Requirements

### Requirement: Settings section extensibility
Each consuming app MUST be able to add its own settings sections without modifying the shared SettingsDialog framework.

#### Scenario: Main app sections
- **WHEN** MaterialClient main app registers settings sections
- **THEN** it SHALL include sections for: scale, weighing, camera, LPR, system, sound device, printer
- **AND** each section SHALL implement ISettingsSection + ITransientDependency

#### Scenario: Urban sections
- **WHEN** MaterialClient.Urban registers settings sections
- **THEN** it SHALL include the same sections as the main app: scale, weighing, camera, LPR, system, sound device, printer
- **AND** each section SHALL use the shared implementations from MaterialClient.UI (MUST NOT maintain Urban-only duplicate section classes)
- **AND** section DisplayName, fields, LoadAsync/SaveAsync behavior SHALL match the main app for each section

#### Scenario: No section conflicts
- **WHEN** both apps define sections with the same DisplayName
- **THEN** only the sections registered in the running app's assembly SHALL appear
- **AND** sections from the other app SHALL NOT appear (assembly isolation)

## ADDED Requirements

### Requirement: Shared settings section implementations
MaterialClient.UI MUST host the canonical ISettingsSection implementations consumed by both MaterialClient and MaterialClient.Urban.

#### Scenario: Single source for section logic
- **WHEN** either app opens SettingsDialog
- **THEN** all seven sections SHALL resolve from MaterialClient.UI assembly via ABP DI
- **AND** Urban MUST NOT ship parallel section implementations under MaterialClient.Urban/Views/Settings/

#### Scenario: Parity verification
- **WHEN** user opens settings in Urban and navigates each section
- **THEN** each section SHALL display the same setting fields as the main app
- **AND** saving settings in Urban SHALL persist using the same keys and services as the main app
