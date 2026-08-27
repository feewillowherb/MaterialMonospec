## ADDED Requirements

### Requirement: Urban settings expose 城管配置 as first nav item

MaterialClient 系统设置（`SettingsWindow`）SHALL include a navigation item labeled「城管配置」. When the host is MaterialClient.Urban, that item SHALL be visible and SHALL appear as the **first** item in the settings navigation list. Non-Urban clients (including the main MaterialClient and Recycle hosts) MUST NOT show「城管配置」.

#### Scenario: Urban client shows 城管配置 first

- **WHEN** an operator opens 系统设置 from MaterialClient.Urban
- **THEN** the left navigation SHALL list「城管配置」as the first item
- **AND** the item SHALL be visible and selectable

#### Scenario: Non-Urban client hides 城管配置

- **WHEN** an operator opens 系统设置 from a non-Urban MaterialClient host
- **THEN** the navigation MUST NOT display「城管配置」
- **AND** the first visible item SHALL remain the host’s existing default (e.g. 地磅设置)

### Requirement: 城管配置 panel edits Xiaoshan upload config without configVersion

The「城管配置」panel SHALL present the Xiaoshan upload configuration editing surface (structured modes/settings fields from prior slices) **without** displaying or depending on `configVersion`. Opening or selecting the panel SHALL load configuration from the **server** (Get), not from `XiaoshanUploadConfigCaches`.

#### Scenario: Panel loads from server

- **WHEN** the operator opens or selects「城管配置」
- **THEN** the client SHALL fetch the authoritative configuration from UrbanManagement when online
- **AND** the panel SHALL display the server payload
- **AND** the panel MUST NOT show `configVersion` as an operator-facing field

#### Scenario: Panel refresh from server

- **WHEN** the operator requests refresh on「城管配置」
- **THEN** the client SHALL fetch the authoritative configuration from UrbanManagement
- **AND** on success SHALL update the panel from the server payload

### Requirement: Settings save pushes config via LocalEvent; failure discards local edits

When the operator saves 系统设置 and Urban「城管配置」has pending changes, MaterialClient.Urban SHALL publish a named local event (EventData `record`, not a tuple) via `ILocalEventBus`. An Urban local event handler SHALL push the configuration to UrbanManagement through a Service, and SHALL write the outcome to application logs. The settings ViewModel MUST NOT call the UrbanManagement HTTP/Refit API directly.

Server configuration is authoritative. If the push succeeds, the UI SHALL reflect the server-accepted configuration (response or subsequent Get). If the push fails or does not complete successfully, the client SHALL **discard** the local edits, fetch the server configuration, and display it; the client MUST NOT keep an unaligned local draft as the effective configuration.

#### Scenario: Successful push via LocalEvent

- **WHEN** the operator saves 系统设置 with dirty 城管配置 changes
- **AND** the local event handler’s server write succeeds
- **THEN** the UI SHALL present the server configuration
- **AND** the application log SHALL record a successful push

#### Scenario: Failed push discards local and reloads server

- **WHEN** the operator saves 系统设置 with dirty 城管配置 changes
- **AND** the server write fails or does not complete successfully
- **THEN** the client SHALL discard the pending local 城管配置 edits
- **AND** the client SHALL fetch and display the server configuration
- **AND** the user SHALL be informed that the push failed and local edits were discarded
- **AND** hardware/system settings already saved in the same Save action MUST NOT be rolled back solely because Xiaoshan push failed
- **AND** the application log SHALL record the failure

#### Scenario: Clean 城管配置 skips push event

- **WHEN** the operator saves 系统设置
- **AND** 城管配置 has no pending changes
- **THEN** the client MUST NOT publish a Xiaoshan upload config save-requested local event

### Requirement: Client does not use XiaoshanUploadConfigCaches

MaterialClient.Urban SHALL NOT read or write `XiaoshanUploadConfigCaches` (or the `XiaoshanUploadConfigCache` entity) for Xiaoshan upload configuration. This change MUST NOT add or modify EF Core migrations for that table.

#### Scenario: Service path without cache repository

- **WHEN** the Urban client loads, refreshes, or pushes Xiaoshan upload configuration
- **THEN** persistence of that configuration’s client-side state MUST NOT use `XiaoshanUploadConfigCache` / `XiaoshanUploadConfigCaches`
- **AND** no new or modified EF migration SHALL be introduced for this table in this change

### Requirement: Standalone 上报配置 menu is not the primary entry

MaterialClient.Urban SHALL NOT expose a separate main-window menu item「上报配置」as the primary configuration entry once「城管配置」is available in 系统设置.

#### Scenario: Main window menu without 上报配置

- **WHEN** an operator views the Urban main window settings/menu strip
- **THEN** the primary path to edit Xiaoshan upload configuration SHALL be 系统设置 →「城管配置」
- **AND** a standalone「上报配置」menu button MUST NOT remain as the primary entry

## MODIFIED Requirements

### Requirement: Client can load and display server config

MaterialClient.Urban SHALL fetch the authoritative Xiaoshan upload configuration from UrbanManagement and display it in the 系统设置「城管配置」panel (Urban-only). Display MUST NOT depend on a local `XiaoshanUploadConfigCaches` row or on client-side `configVersion` semantics.

#### Scenario: Client refresh from server

- **WHEN** the Urban client loads or refreshes Xiaoshan upload configuration from「城管配置」
- **THEN** the client SHALL request the authoritative configuration from UrbanManagement
- **AND** on success SHALL update the panel from the server payload

### Requirement: Client edits take effect only after successful server push

MaterialClient.Urban MAY allow in-panel editing of Xiaoshan upload configuration in「城管配置」, but edits SHALL be considered effective only after a successful server push triggered via `ILocalEventBus` from 系统设置 Save (when the section is dirty). The settings ViewModel MUST NOT call the API directly. If the push fails or does not complete successfully, the client SHALL discard local edits and reload the server configuration; the client MUST NOT claim a discarded draft is authoritative.

#### Scenario: Successful client push

- **WHEN** the user saves 系统设置 with 城管配置 changes
- **AND** the LocalEvent handler’s UrbanManagement write succeeds
- **THEN** the UI SHALL present the server configuration as current

#### Scenario: Failed client push discards draft

- **WHEN** the user saves 系统设置 with 城管配置 changes
- **AND** UrbanManagement rejects the write or the network call fails
- **THEN** the client SHALL discard the local draft
- **AND** the client SHALL reload and display the server configuration
- **AND** the user SHALL be informed that server sync failed and local edits were discarded
