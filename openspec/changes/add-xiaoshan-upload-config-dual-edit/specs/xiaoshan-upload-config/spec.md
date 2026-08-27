## ADDED Requirements

### Requirement: Server stores authoritative Xiaoshan upload config per project

The system SHALL persist an authoritative Xiaoshan upload configuration bound to a project identifier (`ProId` or equivalent 1:1 with `GovProject`). The configuration SHALL be the source of truth for dual-edit flows. Multi-value types in APIs and persistence mapping SHALL use named records/DTOs, not tuples.

#### Scenario: Create or upsert config for a project

- **WHEN** an authorized operator saves Xiaoshan upload configuration for a project that has no config yet
- **THEN** the system SHALL create and persist the authoritative configuration for that project

#### Scenario: Update existing authoritative config

- **WHEN** an authorized operator saves Xiaoshan upload configuration for a project that already has config
- **THEN** the system SHALL update the stored authoritative configuration
- **AND** subsequent reads SHALL return the updated values

### Requirement: Server exposes get and write APIs for upload config

UrbanManagement SHALL provide application APIs for clients and management UI to get and write the authoritative Xiaoshan upload configuration for a project. Write operations SHALL validate required identity fields (at least project binding) before persisting.

#### Scenario: Client or UI gets authoritative config

- **WHEN** a caller requests Xiaoshan upload configuration for a known project
- **THEN** the system SHALL return the authoritative configuration payload for that project

#### Scenario: Missing project config on get

- **WHEN** a caller requests configuration for a project with no stored config
- **THEN** the system SHALL return a well-defined empty/default configuration or a not-found result documented by the API contract
- **AND** MUST NOT return an ambiguous partial payload

#### Scenario: Write rejected when project binding invalid

- **WHEN** a write request omits or references an invalid project binding
- **THEN** the system SHALL reject the write without persisting

### Requirement: Management UI can edit authoritative config

UrbanManagement management UI SHALL allow an authorized user to view and edit the authoritative Xiaoshan upload configuration for a project and persist changes through the same server write path used by clients.

#### Scenario: Operator edits config on server

- **WHEN** an operator changes configuration fields in the management UI and saves
- **THEN** the authoritative server configuration SHALL reflect the saved values

### Requirement: Client can load and display server config

MaterialClient.Urban SHALL be able to fetch the authoritative Xiaoshan upload configuration from UrbanManagement and display it in a settings or configuration surface.

#### Scenario: Client refresh from server

- **WHEN** the Urban client loads or refreshes Xiaoshan upload configuration
- **THEN** the client SHALL request the authoritative configuration from UrbanManagement
- **AND** on success SHALL replace its local aligned cache with the server payload

### Requirement: Client edits take effect only after server accept and align

MaterialClient.Urban MAY allow local editing of Xiaoshan upload configuration, but the edit SHALL be considered effective only after UrbanManagement accepts the write and the client realigns its local cache to the server response (or a subsequent successful get). Failed writes SHALL leave the client in a non-aligned/draft state and MUST NOT claim server authority was updated.

#### Scenario: Successful client write-back

- **WHEN** the user saves configuration changes on the client
- **AND** UrbanManagement accepts the write
- **THEN** the client SHALL update its local aligned cache from the server-accepted payload
- **AND** the UI SHALL present the configuration as aligned with the server

#### Scenario: Failed client write-back

- **WHEN** the user saves configuration changes on the client
- **AND** UrbanManagement rejects the write or the network call fails
- **THEN** the client MUST NOT mark the draft as aligned authoritative state
- **AND** the user SHALL be informed that server sync failed

### Requirement: Config model is extensible for later mode slices

The persisted and API configuration model in this change SHALL use an extensible structure (envelope) that can later hold Weighbridge/Gate/Product mode settings without requiring a breaking rename of the capability. This change DOES NOT require implementing mode multi-select or field-mapping behavior.

#### Scenario: Envelope accepts future mode section

- **WHEN** the configuration schema is inspected after this change
- **THEN** it SHALL provide a defined place (property/section) for future mode-specific settings
- **AND** absence of populated mode settings SHALL still allow get/write of the base configuration
