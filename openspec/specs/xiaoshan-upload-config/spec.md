# Xiaoshan Upload Config Specification

## Purpose

定义按项目绑定的萧山上报权威配置：UrbanManagement 存储与 Get/Write API、乐观并发 `configVersion`、结构化 modes/settings 信封，以及 MaterialClient.Urban 在系统设置「城管配置」中的本地镜像。客户端保存 MUST NOT 向 UrbanManagement 推送配置。

## Requirements

### Requirement: Server stores authoritative Xiaoshan upload config per project

The system SHALL persist an authoritative Xiaoshan upload configuration bound to a project identifier (`ProjectId` 1:1 with `GovProject`). The configuration SHALL be the source of truth for dual-edit flows. Multi-value types in APIs and persistence mapping SHALL use named records/DTOs, not tuples.

The persisted model SHALL include at least: `DisplayName`, `Remark`, `ModesJson`, `SettingsJson`, and monotonic `ConfigVersion`.

#### Scenario: Create or upsert config for a project

- **WHEN** an authorized operator saves Xiaoshan upload configuration for a project that has no config yet
- **THEN** the system SHALL create and persist the authoritative configuration for that project with `ConfigVersion` equal to 1

#### Scenario: Update existing authoritative config

- **WHEN** an authorized operator saves Xiaoshan upload configuration for a project that already has config
- **AND** the write is accepted
- **THEN** the system SHALL update the stored authoritative configuration
- **AND** subsequent reads SHALL return the updated values

### Requirement: Server exposes get and write APIs for upload config

UrbanManagement SHALL provide application APIs (`GetByProjectId` / `Write`) for clients and management UI to get and write the authoritative Xiaoshan upload configuration for a project. Write operations SHALL validate required identity fields (at least project binding) before persisting. Write SHALL return a named result record that distinguishes success, version conflict, and other failure (not a tuple).

#### Scenario: Client or UI gets authoritative config

- **WHEN** a caller requests Xiaoshan upload configuration for a known project
- **THEN** the system SHALL return the authoritative configuration payload for that project

#### Scenario: Missing project config on get

- **WHEN** a caller requests configuration for a project with no stored config
- **THEN** the system SHALL return a well-defined empty configuration (`XiaoshanUploadConfigDto.Empty`) with `configVersion` equal to 0 and materialized default envelopes
- **AND** MUST NOT return an ambiguous partial payload

#### Scenario: Write rejected when project binding invalid

- **WHEN** a write request omits or references an invalid project binding
- **THEN** the system SHALL reject the write without persisting

### Requirement: Config payload includes monotonic configVersion

The authoritative Xiaoshan upload configuration SHALL expose a monotonic `configVersion` (non-negative integer). An absent server config SHALL be represented with `configVersion` equal to `0`. Multi-value API types SHALL use named records/DTOs, not tuples.

#### Scenario: Empty config returns version zero

- **WHEN** a caller gets configuration for a project with no stored authoritative row
- **THEN** the response SHALL include `configVersion` equal to `0`

#### Scenario: Successful write increments version

- **WHEN** a write is accepted against the current authoritative configuration
- **THEN** the persisted `configVersion` SHALL increase by exactly one relative to the pre-write value
- **AND** the write response SHALL return the new `configVersion`

### Requirement: Write uses expectedConfigVersion for conflict detection

Write requests SHALL include `expectedConfigVersion`. For clients with `clientProtocolVersion` **2 or higher**, the server SHALL accept the write only when `expectedConfigVersion` equals the current authoritative `configVersion` (including `0` for first create). On mismatch the server MUST NOT persist the write and MUST return a conflict outcome that includes the current authoritative configuration snapshot.

For clients with `clientProtocolVersion` **1** (legacy) writing against an **existing** authoritative row with `ConfigVersion` greater than zero, the server SHALL NOT require `expectedConfigVersion` to match; it SHALL instead apply the legacy merge rules defined in `xiaoshan-upload-legacy-compat` and increment `configVersion` on successful merge.

#### Scenario: Matching expected version accepts write (v2+)

- **WHEN** a v2 or v3 write is submitted with `expectedConfigVersion` equal to the stored `configVersion`
- **THEN** the server SHALL persist the update and return success with the incremented version

#### Scenario: Stale expected version rejects write (v2+)

- **WHEN** a v2 or v3 write is submitted with `expectedConfigVersion` not equal to the stored `configVersion`
- **THEN** the server SHALL reject the write without changing the authoritative row
- **AND** the conflict outcome SHALL include the current authoritative configuration including its `configVersion`

#### Scenario: Legacy v1 merge skips expected version gate

- **WHEN** a v1 write is submitted against an existing authoritative row with `ConfigVersion` greater than zero
- **AND** `expectedConfigVersion` is zero or stale
- **THEN** the server MAY apply legacy merge per `xiaoshan-upload-legacy-compat`
- **AND** SHALL NOT return a version conflict solely due to stale `expectedConfigVersion`

### Requirement: Config model uses structured mode and settings envelopes

The persisted and API configuration model SHALL use a versioned structured envelope for `ModesJson` and `SettingsJson` that holds Weighbridge/Gate/Product mode settings and static field mappings. Get and Write SHALL serialize and deserialize these envelopes. For protocol v3, invalid schema on Write SHALL be rejected. Raw JSON MAY remain as a secondary diagnostic path in management UI but MUST NOT be the only editing surface.

#### Scenario: Envelope accepts populated mode settings

- **WHEN** configuration is saved with structured mode and settings envelopes
- **THEN** `ModesJson` and `SettingsJson` SHALL persist canonical JSON for those envelopes
- **AND** a subsequent get SHALL round-trip the structured content

#### Scenario: Invalid modes envelope rejected on write

- **WHEN** a v3 write submits `ModesJson` that fails schema validation (for example no enabled modes or placeholder `{}`)
- **THEN** the server SHALL reject the write without incrementing `configVersion`

#### Scenario: Empty legacy JSON materializes defaults on read

- **WHEN** a get returns configuration whose `ModesJson` is `{}` or legacy placeholder
- **THEN** the API SHALL materialize default mode selection with Weighbridge enabled
- **AND** SHALL present settings envelope defaults without requiring manual JSON migration

### Requirement: Management UI can edit authoritative config

UrbanManagement management UI (ProjectManagement 「上报配置」) SHALL allow an authorized user to view and edit the authoritative Xiaoshan upload configuration for a project and persist changes through the same server write path used by clients. The UI SHALL display the authoritative `configVersion` and SHALL submit protocol version 3 with `expectedConfigVersion`.

#### Scenario: Operator edits config on server

- **WHEN** an operator changes configuration fields in the management UI and saves
- **THEN** the authoritative server configuration SHALL reflect the saved values

#### Scenario: Operator sees version on server UI

- **WHEN** an operator opens Xiaoshan upload configuration for a project
- **THEN** the UI SHALL show the authoritative `configVersion`

### Requirement: Urban settings expose 城管配置 as last nav item

MaterialClient 系统设置（`SettingsWindow`）SHALL include a navigation item labeled「城管配置」. When the host is MaterialClient.Urban (Urban mode and Xiaoshan upload facade available), that item SHALL be visible and SHALL appear as the **last** item in the settings navigation list. Non-Urban clients (including the main MaterialClient and Recycle hosts) MUST NOT show「城管配置」.

#### Scenario: Urban client shows 城管配置 last

- **WHEN** an operator opens 系统设置 from MaterialClient.Urban
- **THEN** the left navigation SHALL list「城管配置」as the last item
- **AND** the item SHALL be visible and selectable
- **AND** the default selected section SHALL remain the host’s existing default (e.g. 地磅设置)

#### Scenario: Non-Urban client hides 城管配置

- **WHEN** an operator opens 系统设置 from a non-Urban MaterialClient host
- **THEN** the navigation MUST NOT display「城管配置」
- **AND** the first visible item SHALL remain the host’s existing default (e.g. 地磅设置)

### Requirement: 城管配置 panel edits Xiaoshan upload config without configVersion UI

The「城管配置」panel SHALL present structured mode editing (enabled modes and per-mode parameters) **without** displaying `configVersion` as an operator-facing field. Opening the panel SHALL load the local Urban settings mirror. Settings UI MUST NOT pull or refresh from the server on open. The client MUST NOT persist a `XiaoshanUploadConfigCaches` table. Saving settings MUST NOT push Xiaoshan upload config to UrbanManagement.

#### Scenario: Panel loads from local Urban settings

- **WHEN** the operator opens or selects「城管配置」
- **THEN** the client SHALL display configuration from `SettingsEntity.UrbanSettingsJson` (`UrbanSettings.XiaoshanUpload`)
- **AND** the panel MUST NOT show `configVersion` as an operator-facing field
- **AND** the settings UI MUST NOT fetch UrbanManagement Get solely to populate the panel on open

### Requirement: Client persists Urban settings in UrbanSettingsJson

MaterialClient SHALL persist Urban aggregated settings in `SettingsEntity.UrbanSettingsJson` (deserialized as `UrbanSettings`). Xiaoshan upload local mirror SHALL live under `UrbanSettings.XiaoshanUpload` (display name, remark, modes JSON, settings JSON). The local mirror SHALL NOT store `configVersion`.

#### Scenario: Save writes UrbanSettingsJson without server push

- **WHEN** the operator saves 系统设置 with Urban config changes
- **THEN** the client SHALL persist `UrbanSettingsJson` with the current Xiaoshan upload form values
- **AND** MUST NOT publish a Xiaoshan LocalEvent, call a config Facade, or Write UrbanManagement upload config

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

#### Scenario: No client config push

- **WHEN** settings are saved on the Urban client
- **THEN** the client MUST NOT call UrbanManagement Xiaoshan upload config Write
- **AND** types used only for that sync SHALL be deleted on both MaterialClient and UrbanManagement rather than left unused

### Requirement: Standalone 上报配置 menu is not the primary entry

MaterialClient.Urban SHALL NOT expose a separate main-window menu item「上报配置」or a standalone `XiaoshanUploadConfigWindow` as the primary configuration entry. The primary path SHALL be 系统设置 →「城管配置」.

#### Scenario: Main window menu without 上报配置

- **WHEN** an operator views the Urban main window settings/menu strip
- **THEN** the primary path to edit Xiaoshan upload configuration SHALL be 系统设置 →「城管配置」
- **AND** a standalone「上报配置」menu button MUST NOT remain as the primary entry
