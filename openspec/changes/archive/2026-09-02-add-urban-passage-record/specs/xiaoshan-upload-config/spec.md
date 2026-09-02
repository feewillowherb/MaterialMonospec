## MODIFIED Requirements

### Requirement: 城管配置 panel edits Xiaoshan upload config without configVersion UI

The「城管配置」panel SHALL **not** present Weighbridge/Gate/Product enable toggles or per-mode 进出场/场地 parameters. The panel MUST NOT display `configVersion` as an operator-facing field. Opening the panel SHALL load the local Urban settings mirror for any remaining static Urban fields (for example access-code display). Settings UI MUST NOT pull or refresh from the server on open. The client MUST NOT persist a `XiaoshanUploadConfigCaches` table. Saving settings MUST NOT push Xiaoshan upload config to UrbanManagement. Three-mode and in/out/site runtime SHALL come from LPR rows (`lpr-site-type`).

#### Scenario: Panel loads from local Urban settings

- **WHEN** the operator opens or selects「城管配置」
- **THEN** the client SHALL display remaining configuration from `SettingsEntity.UrbanSettingsJson` (`UrbanSettings.XiaoshanUpload`) if any static fields remain
- **AND** the panel MUST NOT show `configVersion` as an operator-facing field
- **AND** the panel MUST NOT show three-mode enable or 进出场/场地 editors
- **AND** the settings UI MUST NOT fetch UrbanManagement Get solely to populate the panel on open

### Requirement: Settings persist Xiaoshan mode fields into UrbanSettingsJson

MaterialClient SHALL persist remaining Urban aggregated settings in `SettingsEntity.UrbanSettingsJson` as `UrbanSettings`. `SettingsWindowViewModel` MUST NOT parse Xiaoshan JSON itself and MUST NOT reference the Urban project. Conversions MUST use named records and type-owned/`From*` methods, not tuples and not a mapper Service.

Weighbridge/Gate/Product enabled flags, Weighbridge in/out, Gate in/out and site type, and Product in/out and site type MUST NOT be operator-edited in 城管配置 and MUST NOT be the runtime source of truth. Those capabilities live on Urban LPR rows. Site access code display SHALL use license `AccessCode` and MUST NOT be written to `UrbanSettingsJson`. Leftover `ModesJson` enabled or per-mode keys MUST be ignored on load.

This change SHALL NOT require or verify that local Urban settings are synchronized to UrbanManagement.

#### Scenario: Save does not persist three-mode enables from 城管配置

- **WHEN** the operator saves 系统设置 on an Urban host
- **THEN** the save SHALL complete without Xiaoshan LocalEvent, config Facade, or UrbanManagement config Write
- **AND** acceptance SHALL NOT include a client-to-server config sync check
- **AND** the client MUST NOT write 三模式启用 or 进出场/场地 from 城管配置 as the live source for recognition routing

#### Scenario: Reload ignores ModesJson mode switches

- **WHEN** settings load applies `UrbanSettings.XiaoshanUpload`
- **THEN** the ViewModel MUST NOT restore Weighbridge/Gate/Product enabled flags or 进出场/场地 from `ModesJson` into 城管配置

#### Scenario: No client config push

- **WHEN** settings are saved on the Urban client
- **THEN** the client MUST NOT call UrbanManagement Xiaoshan upload config Write
- **AND** types used only for that sync SHALL be deleted on both MaterialClient and UrbanManagement rather than left unused
