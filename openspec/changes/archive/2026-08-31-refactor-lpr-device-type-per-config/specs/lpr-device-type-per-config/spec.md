## ADDED Requirements

### Requirement: LPR vendor type is stored per device config

Each `LicensePlateRecognitionConfig` MUST persist `DeviceType` (`LprDeviceType`). Runtime LPR start, capture, online check, test capture, and gate I/O gating MUST use that per-row value. `SystemSettings.LprDeviceType` MUST NOT be the authoritative vendor for those paths after load/backfill.

#### Scenario: New config saves DeviceType from add dialog

- **WHEN** the operator adds an LPR device and selects `Vzvision` then saves 系统设置
- **THEN** that row in `LicensePlateRecognitionConfigsJson` SHALL contain `DeviceType` equal to `Vzvision`

#### Scenario: Mixed vendors start both SDKs

- **WHEN** saved configs include at least one Hikvision row and one Vzvision row
- **AND** device start runs
- **THEN** the host SHALL start Hikvision LPR listening and Vzvision LPR listening
- **AND** MUST NOT start only one vendor because of a global setting

#### Scenario: Missing DeviceType backfilled from legacy global

- **WHEN** settings load and a config row has no usable `DeviceType`
- **AND** `SystemSettings.LprDeviceType` is `Hikvision`
- **THEN** that row SHALL be treated as `Hikvision` for UI and runtime
- **AND** a subsequent save SHALL persist `DeviceType` on the row

#### Scenario: Global setting is not the runtime authority

- **WHEN** `SystemSettings.LprDeviceType` is `Hikvision`
- **AND** a config row’s persisted `DeviceType` is `Vzvision`
- **THEN** capture, online probe, and SDK start for that row SHALL use `Vzvision`
- **AND** MUST NOT use the global Hikvision value for that row

#### Scenario: Online badge remains any-online

- **WHEN** multiple LPR configs exist with different `DeviceType` values
- **THEN** the LPR online indicator SHALL be true if any row is online using that row’s type
