## MODIFIED Requirements

### Requirement: Write uses expectedConfigVersion for conflict detection

Write requests SHALL include `expectedConfigVersion`. For clients with `clientProtocolVersion` **2 or higher**, the server SHALL accept the write only when `expectedConfigVersion` equals the current authoritative `configVersion` (including `0` for first create). On mismatch the server MUST NOT persist the write and MUST return a conflict outcome that includes the current authoritative configuration snapshot.

For clients with `clientProtocolVersion` **1** (legacy) writing against an **existing** authoritative row, the server SHALL NOT require `expectedConfigVersion` to match; it SHALL instead apply the legacy merge rules defined in `xiaoshan-upload-legacy-compat` and increment `configVersion` on successful merge.

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
