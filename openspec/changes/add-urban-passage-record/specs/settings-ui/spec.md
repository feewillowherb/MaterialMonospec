## ADDED Requirements

### Requirement: Urban AddLpr sets in/out and site; 城管配置 omits modes

On an Urban host, `AddLprDialog` (add and edit) MUST present 进出场 (`UrbanInOutType`) and 场地 (`UrbanSiteType`) in addition to LPR site type (地磅/卡口/成品). Confirming the dialog MUST write those values onto that `LicensePlateRecognitionConfig` row. The「城管配置」panel MUST NOT show Weighbridge/Gate/Product enable toggles, 进出场, or 场地. Non-Urban hosts MUST NOT show 进出场 or 场地 on AddLpr.

#### Scenario: Urban add LPR includes 场地

- **WHEN** an Urban operator adds an LPR device and selects 消纳 as 场地 and 出 as 进出场
- **THEN** the persisted LPR row MUST store disposal and exit
- **AND** 城管配置 MUST NOT be required to save those values

#### Scenario: 城管配置 has no mode or in/out editors

- **WHEN** an Urban operator opens「城管配置」
- **THEN** the panel MUST NOT display three-mode enable toggles
- **AND** MUST NOT display 进出场 or 场地 editors for any mode
