## MODIFIED Requirements

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
