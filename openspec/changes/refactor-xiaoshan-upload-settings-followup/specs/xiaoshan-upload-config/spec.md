## ADDED Requirements

### Requirement: Urban config form mapping lives in a Service with named records

MaterialClient SHALL provide a Service in **Common** that maps between the 城管配置 form state and `ModesJson` / `SettingsJson` plus preserved static fields (`DisplayName`, `Remark`, `buildLicenseNo`, `areaCode`, `spaceName`). Multi-value types SHALL be named records, not tuples. `SettingsWindowViewModel` MUST NOT parse or serialize Xiaoshan envelopes directly and MUST NOT reference the Urban project.

#### Scenario: Load form from local urban settings

- **WHEN** settings load applies `UrbanSettings.XiaoshanUpload`
- **THEN** the ViewModel SHALL obtain form fields via the mapping Service
- **AND** SHALL retain preserved statics for the next push

#### Scenario: Build draft for LocalEvent push

- **WHEN** the operator saves with dirty 城管配置
- **THEN** the ViewModel SHALL obtain `XiaoshanUploadConfigDraft` from the mapping Service
- **AND** SHALL publish that draft via the existing LocalEvent path

### Requirement: Client validates at least one enabled mode before push

Before publishing the Xiaoshan upload save LocalEvent, the Urban client SHALL reject a form with no enabled modes. The settings window SHALL remain open and the user SHALL be informed.

#### Scenario: All modes unchecked blocks push

- **WHEN** the operator saves 系统设置 with 城管配置 dirty
- **AND** Weighbridge, Gate, and Product are all disabled
- **THEN** the client MUST NOT publish the Xiaoshan upload save-requested event
- **AND** the user SHALL be informed that at least one mode must remain enabled
