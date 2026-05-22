## ADDED Requirements

### Requirement: Document camera enabled configuration property

The system MUST expose `DocumentCameraEnabled` as a boolean on `SystemSettings` (serialized with settings storage), controlling whether the document camera (高拍仪) participates in application startup and status bar visibility.

#### Scenario: Property default

- **WHEN** a new `SystemSettings` instance is created without an explicit value
- **THEN** `DocumentCameraEnabled` MUST default to `false`

#### Scenario: Persist enable flag

- **WHEN** user saves settings with document camera enabled or disabled
- **THEN** the system MUST persist `DocumentCameraEnabled` through `ISettingsService`
- **AND** MUST restore the saved value on next application launch

#### Scenario: Startup skips document camera when disabled

- **WHEN** the application starts with `DocumentCameraEnabled` equal to `false`
- **THEN** the device manager MUST NOT start the document camera / USB camera service as an active peripheral
- **AND** the device status bar MUST NOT include a document camera indicator

#### Scenario: Startup includes document camera when enabled

- **WHEN** the application starts with `DocumentCameraEnabled` equal to `true`
- **THEN** the device manager MUST attempt to start the document camera service according to existing USB camera startup rules
- **AND** the device status bar MUST include a document camera indicator subject to connection state
