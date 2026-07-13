# default-delivery-type-setting Specification

## Purpose
TBD - created by archiving change add-delivery-type-default-setting. Update Purpose after archive.
## Requirements
### Requirement: Default delivery type is persisted in system settings

The system SHALL persist an operator-configurable default `DeliveryType` as part of the system settings. The value SHALL be one of `Receiving` (收料) or `Sending` (发料). Persistence SHALL reuse the existing system settings store (the `SystemSettings` JSON blob) so that no database schema migration is required.

#### Scenario: First run with no stored preference
- **WHEN** the application starts and no default delivery type has ever been saved
- **THEN** the effective default delivery type SHALL be `Receiving`

#### Scenario: Preference survives serialization round-trip
- **WHEN** a default delivery type of `Sending` is saved and the settings are reloaded from storage
- **THEN** the loaded default delivery type SHALL equal `Sending`

#### Scenario: Corrupted or unknown stored value falls back safely
- **WHEN** the stored value cannot be mapped to a defined `DeliveryType` member
- **THEN** the system SHALL fall back to `Receiving` instead of throwing

### Requirement: Default delivery type is configurable from the settings UI

The settings window SHALL expose a control in the 系统设置 (System Settings) pane that lets the operator choose the default delivery type. The control SHALL offer exactly the options 收料 (`Receiving`) and 发料 (`Sending`). The option display labels SHALL originate from a single source (no duplicated 收料/发料 literals in the new code).

#### Scenario: Loading the settings window shows the current preference
- **WHEN** the operator opens the settings window and the persisted default is `Sending`
- **THEN** the default-delivery-type control SHALL display 发料 as the selected option

#### Scenario: Saving a new preference persists it
- **WHEN** the operator selects 发料 in the default-delivery-type control and saves settings
- **THEN** the persisted default delivery type SHALL become `Sending`

#### Scenario: Saving without changing the preference preserves it
- **WHEN** the operator saves settings without touching the default-delivery-type control
- **THEN** the previously persisted default delivery type SHALL remain unchanged

### Requirement: Default delivery type is applied at attended-weighing startup

On attended-weighing first page load, the system SHALL read the persisted default delivery type and apply it to the weighing state manager via the existing delivery-type change path, instead of leaving the boot mode hardcoded to `Receiving`.

#### Scenario: Saved Sending is applied at boot
- **WHEN** the application boots with a persisted default of `Sending` and the attended-weighing view initializes
- **THEN** the weighing state manager's current delivery type SHALL become `Sending`
- **AND** the on-screen mode indicator SHALL reflect 发料

#### Scenario: Saved Receiving keeps current state with no spurious event
- **WHEN** the application boots with a persisted default of `Receiving` (which already equals the manager's seed value)
- **THEN** the current delivery type SHALL remain `Receiving`
- **AND** the system SHALL NOT emit a delivery-type-changed event

#### Scenario: Operator toggle still overrides within a session
- **WHEN** the operator presses the 发料 or 收料 toggle during a running session
- **THEN** the current delivery type SHALL change immediately
- **AND** that runtime choice SHALL NOT overwrite the persisted default (the default is set only via the settings UI)

### Requirement: Default delivery type does not affect out-of-scope modes

The default delivery type setting SHALL be applied only on the attended-weighing startup path. Modes that do not use `DeliveryType` (notably the Urban client) SHALL be unaffected by this setting.

#### Scenario: Urban client is unaffected
- **WHEN** the Urban client boots with any persisted default delivery type
- **THEN** Urban behavior SHALL remain unchanged, because the Urban module does not reference `DeliveryType`

