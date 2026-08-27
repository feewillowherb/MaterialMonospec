## ADDED Requirements

### Requirement: Upload config supports multi-select Weighbridge Gate Product modes

The Xiaoshan upload configuration SHALL support enabling zero or more of the modes `Weighbridge`, `Gate`, and `Product` as defined by the platform upload design. When no mode selection is stored, the system SHALL treat `Weighbridge` as the sole enabled mode. At least one mode MUST remain enabled for a valid persisted configuration.

#### Scenario: Default mode when envelope empty

- **WHEN** configuration is loaded and the modes envelope is empty or absent
- **THEN** the effective enabled modes SHALL include `Weighbridge` only

#### Scenario: Multiple modes enabled

- **WHEN** an operator or client saves configuration with `Weighbridge` and `Gate` enabled
- **THEN** the persisted authoritative configuration SHALL record both modes as enabled
- **AND** subsequent reads SHALL return both as enabled

#### Scenario: Reject save with no enabled mode

- **WHEN** a write attempts to persist a configuration with no enabled modes
- **THEN** the server SHALL reject the write without changing the authoritative row

### Requirement: Each enabled mode has configurable mode-level parameters

For each enabled mode, the configuration SHALL allow setting mode-level parameters including at least `deviceID` (Gate/Product semantics), `siteType`, and `inOutType` (Weighbridge semantics). Mode settings SHALL be stored in the structured modes envelope serialized to `ModesJson`.

#### Scenario: Weighbridge mode parameters saved

- **WHEN** Weighbridge is enabled and `inOutType` is set to `0`
- **THEN** the persisted modes envelope SHALL include Weighbridge settings with that `inOutType`

#### Scenario: Gate mode parameters saved

- **WHEN** Gate is enabled and `deviceID` is set to `01` and `siteType` to `1`
- **THEN** the persisted modes envelope SHALL include Gate settings with those values

### Requirement: Dual-end UI exposes structured mode editing

UrbanManagement management UI and MaterialClient.Urban upload-config UI SHALL provide structured controls for mode multi-select and per-mode parameters instead of requiring operators to edit raw JSON as the primary path.

#### Scenario: Operator toggles modes on server UI

- **WHEN** an operator opens the upload config dialog for a project
- **THEN** the UI SHALL show checkboxes or equivalent for Weighbridge, Gate, and Product
- **AND** SHALL show parameter fields for each enabled mode

#### Scenario: Client user edits modes structurally

- **WHEN** the Urban client opens the Xiaoshan upload config window
- **THEN** the UI SHALL allow editing enabled modes and their parameters through structured fields
- **AND** saving SHALL submit the structured payload through the existing write API with `expectedConfigVersion`
