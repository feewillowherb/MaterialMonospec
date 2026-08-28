## ADDED Requirements

### Requirement: Urban config form mapping lives in a Service with named records

MaterialClient SHALL provide a Service in **Common** that maps between the 城管配置 UI fields (enabled modes and per-mode inOut/device/site indexes) and `ModesJson`. The mapper MUST NOT round-trip `DisplayName`, `Remark`, or static settings (`buildLicenseNo`, `areaCode`, `spaceName`) through the settings form. Multi-value types SHALL be named records, not tuples. `SettingsWindowViewModel` MUST NOT parse or serialize Xiaoshan envelopes directly and MUST NOT reference the Urban project.

#### Scenario: Load form from local urban settings

- **WHEN** settings load applies `UrbanSettings.XiaoshanUpload`
- **THEN** the ViewModel SHALL obtain UI form fields via the mapping Service from `ModesJson`
- **AND** MUST NOT load `DisplayName` or `Remark` into the settings form

#### Scenario: Build draft for LocalEvent push

- **WHEN** the operator saves with dirty 城管配置
- **THEN** the ViewModel SHALL obtain a draft whose `ModesJson` reflects only UI mode fields
- **AND** SHALL publish that draft via the existing LocalEvent path

#### Scenario: Push does not wipe server static fields

- **WHEN** the Urban client writes configuration after a successful Get of an existing row
- **THEN** the write SHALL keep the server `DisplayName`, `Remark`, and `SettingsJson`
- **AND** SHALL replace `ModesJson` with the UI-built modes envelope

### Requirement: Client validates at least one enabled mode before push

Before publishing the Xiaoshan upload save LocalEvent, the Urban client SHALL reject a form with no enabled modes. The settings window SHALL remain open and the user SHALL be informed.

#### Scenario: All modes unchecked blocks push

- **WHEN** the operator saves 系统设置 with 城管配置 dirty
- **AND** Weighbridge, Gate, and Product are all disabled
- **THEN** the client MUST NOT publish the Xiaoshan upload save-requested event
- **AND** the user SHALL be informed that at least one mode must remain enabled
