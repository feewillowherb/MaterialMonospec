## ADDED Requirements

### Requirement: Server records a change log entry on each accepted write

When an authoritative Xiaoshan upload configuration write is accepted, the system SHALL append a change log entry in the same unit of work. Each entry SHALL record at least: project id, resulting `configVersion`, source (Client or Server), actor identifier, a short summary of the change, and creation time. Change logs MUST NOT replace `configVersion` as the runtime consistency key.

#### Scenario: Accepted write creates log row

- **WHEN** a write is accepted and the authoritative `configVersion` becomes N
- **THEN** a change log entry SHALL exist for that project with `configVersion` equal to N
- **AND** the entry SHALL identify source and actor

#### Scenario: Rejected write creates no log row

- **WHEN** a write is rejected due to version conflict
- **THEN** the system MUST NOT append a change log entry for that attempt

### Requirement: Change logs are queryable per project

UrbanManagement SHALL provide an API to list recent change log entries for a project, ordered by newest first, using named DTOs/records (no tuples).

#### Scenario: List recent logs

- **WHEN** a caller requests change logs for a project with prior accepted writes
- **THEN** the system SHALL return entries for that project ordered from newest to oldest
- **AND** each entry SHALL include `configVersion`, source, actor, summary, and creation time

#### Scenario: Project with no logs

- **WHEN** a caller requests change logs for a project with no accepted writes
- **THEN** the system SHALL return an empty list

### Requirement: Management UI can view recent change logs

The UrbanManagement management UI for Xiaoshan upload configuration SHALL allow an operator to view recent change log entries for the selected project.

#### Scenario: Operator opens log list

- **WHEN** an operator views Xiaoshan upload configuration for a project that has change logs
- **THEN** the UI SHALL display recent log entries including version, source, actor, summary, and time
