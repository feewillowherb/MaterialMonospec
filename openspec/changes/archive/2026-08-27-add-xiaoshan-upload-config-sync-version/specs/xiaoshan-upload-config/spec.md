## ADDED Requirements

### Requirement: Config payload includes monotonic configVersion

The authoritative Xiaoshan upload configuration and its client-aligned cache SHALL expose a monotonic `configVersion` (non-negative integer). An absent server config SHALL be represented with `configVersion` equal to `0`. Multi-value API types SHALL use named records/DTOs, not tuples.

#### Scenario: Empty config returns version zero

- **WHEN** a caller gets configuration for a project with no stored authoritative row
- **THEN** the response SHALL include `configVersion` equal to `0`

#### Scenario: Successful write increments version

- **WHEN** a write is accepted against the current authoritative configuration
- **THEN** the persisted `configVersion` SHALL increase by exactly one relative to the pre-write value
- **AND** the write response SHALL return the new `configVersion`

### Requirement: Write uses expectedConfigVersion for conflict detection

Write requests SHALL include `expectedConfigVersion`. The server SHALL accept the write only when `expectedConfigVersion` equals the current authoritative `configVersion` (including `0` for first create). On mismatch the server MUST NOT persist the write and MUST return a conflict outcome that includes the current authoritative configuration snapshot.

#### Scenario: Matching expected version accepts write

- **WHEN** a write is submitted with `expectedConfigVersion` equal to the stored `configVersion`
- **THEN** the server SHALL persist the update and return success with the incremented version

#### Scenario: Stale expected version rejects write

- **WHEN** a write is submitted with `expectedConfigVersion` not equal to the stored `configVersion`
- **THEN** the server SHALL reject the write without changing the authoritative row
- **AND** the conflict outcome SHALL include the current authoritative configuration including its `configVersion`

### Requirement: Client aligns on version and refreshes when behind

MaterialClient.Urban SHALL store `configVersion` in the local aligned cache. After a successful get or write, the client SHALL set its aligned cache to the server payload including version. When a write returns conflict or the client detects it is behind, the client SHALL refresh from the server, overwrite the aligned cache, and MUST NOT mark the rejected draft as aligned.

#### Scenario: Client refresh stores server version

- **WHEN** the client successfully refreshes configuration from the server
- **THEN** the local aligned cache SHALL match the server `configVersion` and payload
- **AND** the UI SHALL present the configuration as aligned

#### Scenario: Client write conflict keeps draft unaligned

- **WHEN** the client save receives a version conflict
- **THEN** the client SHALL refresh or apply the returned authoritative snapshot to the aligned cache
- **AND** the rejected draft MUST remain unaligned / not claimed as effective
- **AND** the user SHALL be informed of the conflict

### Requirement: UI surfaces configVersion

Management UI and MaterialClient.Urban upload-config UI SHALL display the current `configVersion` for the loaded configuration.

#### Scenario: Operator sees version on server UI

- **WHEN** an operator opens Xiaoshan upload configuration for a project
- **THEN** the UI SHALL show the authoritative `configVersion`

#### Scenario: Client sees version on config window

- **WHEN** the Urban client opens the Xiaoshan upload config window after a successful refresh
- **THEN** the UI SHALL show the aligned `configVersion`
