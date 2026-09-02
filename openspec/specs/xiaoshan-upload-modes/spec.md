# Xiaoshan Upload Modes Specification

## Purpose

定义萧山上报配置的 Weighbridge / Gate / Product 多选模式及分模式参数，以及双端结构化编辑（非 raw JSON 主路径）。
## Requirements
### Requirement: Upload config supports multi-select Weighbridge Gate Product modes

The Xiaoshan upload configuration SHALL support enabling zero or more of the modes `Weighbridge`, `Gate`, and `Product`. When no mode selection is stored, the system SHALL treat `Weighbridge` as the sole enabled mode. At least one mode MUST remain enabled for a valid persisted configuration under protocol v3.

#### Scenario: Default mode when envelope empty

- **WHEN** configuration is loaded and the modes envelope is empty or absent
- **THEN** the effective enabled modes SHALL include `Weighbridge` only

#### Scenario: Multiple modes enabled

- **WHEN** an operator or client saves configuration with `Weighbridge` and `Gate` enabled
- **THEN** the persisted authoritative configuration SHALL record both modes as enabled
- **AND** subsequent reads SHALL return both as enabled

#### Scenario: Reject save with no enabled mode

- **WHEN** a v3 write attempts to persist a configuration with no enabled modes
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

UrbanManagement management UI MAY continue to provide structured controls for mode multi-select and per-mode parameters (server authoritative envelope is unchanged in this change). MaterialClient.Urban「城管配置」MUST NOT provide mode multi-select or per-mode 进出场/场地 as the primary path. On the Urban client, Weighbridge/Gate/Product capability SHALL be controlled by LPR `LprSiteType` rows, not by editing `ModesJson` enabled flags. MaterialClient SHALL NOT submit three-mode enables through Xiaoshan upload Write in this change (no upload / no config push).

#### Scenario: Operator toggles modes on server UI

- **WHEN** an operator opens the upload config dialog for a project on UrbanManagement
- **THEN** the UI SHALL show checkboxes or equivalent for Weighbridge, Gate, and Product
- **AND** SHALL show parameter fields for each enabled mode

#### Scenario: Client user does not edit modes in 城管配置

- **WHEN** the Urban client opens 系统设置「城管配置」
- **THEN** the UI MUST NOT allow editing Weighbridge/Gate/Product enabled flags or their in/out and site parameters through that panel
- **AND** saving 系统设置 MUST NOT submit those mode flags through the Xiaoshan write API

