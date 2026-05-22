## MODIFIED Requirements

### Requirement: DeviceStatusBar configuration per app
Each consuming app MUST use the same device catalog for the status bar; device list construction SHALL be centralized in MaterialClient.UI.

#### Scenario: Urban device set
- **WHEN** MaterialClient.Urban initializes DeviceStatusBarViewModel
- **THEN** it SHALL show indicators for the same devices as the main app: scale, camera, USB camera, printer, sound device, LPR
- **AND** device display names and ordering SHALL match the main app
- **AND** SHALL NOT omit printer or sound device indicators

#### Scenario: Main app device set
- **WHEN** MaterialClient main app initializes DeviceStatusBarViewModel
- **THEN** it SHALL show indicators for: scale, camera, USB camera, printer, sound device, LPR

## ADDED Requirements

### Requirement: Centralized device status catalog
MaterialClient.UI MUST provide a single implementation that builds and updates the DeviceStatusBar item collection for all consuming apps.

#### Scenario: Shared catalog between apps
- **WHEN** DeviceStatusBarViewModel is constructed in either MaterialClient or MaterialClient.Urban
- **THEN** it SHALL use the same catalog logic to populate Devices
- **AND** SHALL subscribe to the same ILocalEventBus device status events

#### Scenario: Urban status bar parity
- **WHEN** a device connects or disconnects on an Urban deployment with full peripherals
- **THEN** the corresponding indicator SHALL update within 1 second
- **AND** online/offline colors SHALL match the main app (green online, red offline)
