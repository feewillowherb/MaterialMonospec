# Xiaoshan Upload Legacy Compat Specification

## Purpose

定义萧山上报配置 Write 的客户端协议档位：缺省按旧端 v1 merge，当前 Urban 客户端与管理端发送 v3 结构化协议。

## Requirements

### Requirement: Write requests declare client protocol version

`XiaoshanUploadConfigWriteDto` SHALL accept an optional `clientProtocolVersion` integer. When omitted or non-positive, the server SHALL treat the request as protocol version **1** (legacy). MaterialClient.Urban and UrbanManagement management UI SHALL send protocol version **3** on write requests.

#### Scenario: Missing protocol version treated as legacy

- **WHEN** a write request omits `clientProtocolVersion` or sends a non-positive value
- **THEN** the server SHALL classify the request as protocol version 1 for write routing

#### Scenario: Current Urban client sends structured protocol version

- **WHEN** an upgraded MaterialClient.Urban saves Xiaoshan upload configuration
- **THEN** the write request SHALL include `clientProtocolVersion` equal to 3

### Requirement: Legacy protocol v1 merge write preserves structured modes and settings

When `clientProtocolVersion` is 1 and an authoritative configuration row already exists with `ConfigVersion` greater than zero, the server SHALL apply a merge write that updates only safe fields (`DisplayName`, `Remark`). If the client submits empty or legacy placeholder `ModesJson` or `SettingsJson` (for example `{}`), the server MUST NOT replace existing structured envelope content with those placeholders.

#### Scenario: Legacy empty modes does not wipe server envelope

- **WHEN** a v1 write is received for a project whose authoritative config already has structured modes settings
- **AND** the write payload includes `ModesJson` of `{}`
- **THEN** the persisted authoritative `ModesJson` SHALL remain the pre-write structured content
- **AND** the write MAY still update `DisplayName` or `Remark` if provided

#### Scenario: Legacy merge increments config version

- **WHEN** a v1 merge write succeeds for an existing authoritative row
- **THEN** `configVersion` SHALL increase by one
- **AND** a change log entry SHALL be appended indicating a legacy merge

### Requirement: Versioned and structured clients use existing conflict and validation rules

When `clientProtocolVersion` is 2 or higher, the server SHALL require optimistic concurrency via `expectedConfigVersion`. When `clientProtocolVersion` is 3, the server SHALL additionally validate structured modes and settings envelopes.

#### Scenario: v2 stale expected version still conflicts

- **WHEN** a v2 write is received with `expectedConfigVersion` not equal to the stored version
- **THEN** the server SHALL reject the write with a conflict outcome and authoritative snapshot
- **AND** MUST NOT apply a legacy merge

#### Scenario: v3 invalid envelope still rejected

- **WHEN** a v3 write is received with modes envelope failing validation (for example no enabled modes)
- **THEN** the server SHALL reject the write without persisting changes

### Requirement: Get remains backward readable for older clients

The get-by-project configuration API SHALL continue returning the full configuration DTO including `configVersion`, `modesJson`, and `settingsJson`. Older clients that ignore unknown JSON properties SHALL remain able to consume the response without protocol negotiation.

#### Scenario: Old client get ignores new JSON fields

- **WHEN** a legacy client calls get for a project with structured modes settings stored
- **THEN** the response SHALL include the stored JSON strings
- **AND** the client MAY ignore envelope fields it does not understand while still reading base properties
