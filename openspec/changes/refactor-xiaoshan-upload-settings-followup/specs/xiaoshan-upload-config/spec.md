## ADDED Requirements

### Requirement: Settings persist Xiaoshan mode fields into UrbanSettingsJson

MaterialClient SHALL persist 城管配置 core fields into `SettingsEntity.UrbanSettingsJson` as `UrbanSettings.XiaoshanUpload.ModesJson`. Mapping SHALL use a Common Service and named records (not tuples). `SettingsWindowViewModel` MUST NOT parse Xiaoshan JSON itself and MUST NOT reference the Urban project.

Core fields SHALL be: Weighbridge/Gate/Product enabled flags; Weighbridge in/out; Gate in/out and site type; Product in/out and site type. Site access code display SHALL use license `AccessCode` and MUST NOT be written to `UrbanSettingsJson`. Local config SHALL store `ModesJson` only.

This change SHALL NOT require or verify that local Urban settings are synchronized to UrbanManagement.

#### Scenario: Save writes ModesJson from UI

- **WHEN** the operator saves 系统设置 on an Urban host with 城管配置 dirty
- **THEN** `UrbanSettingsJson` SHALL contain `XiaoshanUpload.ModesJson` reflecting the core UI fields
- **AND** that save SHALL complete without Xiaoshan LocalEvent, config Facade, or UrbanManagement config Write
- **AND** acceptance SHALL NOT include a client-to-server config sync check

#### Scenario: Reload restores core fields

- **WHEN** settings load applies `UrbanSettings.XiaoshanUpload`
- **THEN** the ViewModel SHALL obtain the core UI fields via the mapping Service from `ModesJson`

## REMOVED Requirements

### Requirement: Client-to-server Xiaoshan upload config sync

The dual-edit config sync path SHALL be removed and SHALL NOT be accepted as in-scope: MaterialClient LocalEvent/Facade/Refit Get+Write, and UrbanManagement Get/Write AppService, write DTOs, optimistic `configVersion`, management UI for upload **config**, and change log used only for those writes.

#### Scenario: No client config push

- **WHEN** settings are saved on the Urban client
- **THEN** the client MUST NOT call UrbanManagement Xiaoshan upload config Write
- **AND** types used only for that sync SHALL be deleted on both MaterialClient and UrbanManagement rather than left unused
