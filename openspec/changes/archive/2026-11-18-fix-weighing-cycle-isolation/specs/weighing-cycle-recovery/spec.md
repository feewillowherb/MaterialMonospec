## ADDED Requirements

### Requirement: Release the current cycle independently of old record finalization

The system SHALL seal and release a departed cycle independently of successful record finalization. Recovery SHALL use the original CycleId, RecordId and sealed data, never live data from a later vehicle.

#### Scenario: Urban finalization fails

- **WHEN** finalization of a departed vehicle fails
- **THEN** the old record SHALL retain a diagnostic recovery state
- **AND** the next vehicle SHALL be able to create its own record without inheriting the old RecordId or plate cache

#### Scenario: Old finalization completes during the next cycle

- **WHEN** an old record finishes finalization while a new cycle is active
- **THEN** it SHALL modify only the old record and its recovery state
- **AND** it MUST NOT reset the new cycle or clear its vehicle information

### Requirement: Persist and bound finalization recovery

The system SHALL persist versioned recovery information in record ExtraProperties and SHALL perform no more than three automatic retries after the initial finalization failure. Retry delays SHALL be 5, 30 and 120 seconds. Recovery MUST NOT repeat record creation or consume the weighing operation queue slots.

#### Scenario: Retries are exhausted

- **WHEN** all three retries fail
- **THEN** recovery SHALL become Exhausted and stop automatic attempts
- **AND** the record and diagnostic information SHALL be retained without blocking subsequent weighing

#### Scenario: Process restarts during recovery

- **WHEN** the process restarts with a versioned unfinished recovery item
- **THEN** it SHALL resume eligible work using the stored identity and remaining retry allowance
- **AND** it MUST NOT reset the attempt count or infer a new cycle for historical records lacking the versioned data

#### Scenario: Recovery repeats after a successful side effect

- **WHEN** an attempt is repeated after interruption
- **THEN** finalization SHALL be idempotent for the original record
- **AND** it MUST NOT create another weighing record or requeue an already Synced record merely because recovery repeats

### Requirement: Preserve existing upload failure semantics

Missing photos or plate information SHALL NOT by itself block the weighing record's existing synchronization flow. Existing attachment upload failure handling SHALL remain unchanged: failed attachment upload retains Pending for retry. Diagnostic cycle flags MUST NOT independently block synchronization.

#### Scenario: No local photo or plate

- **WHEN** a record eligible under the existing sync flow has no local photos or plate
- **THEN** absence alone SHALL NOT suppress its submission

#### Scenario: Existing attachment upload fails

- **WHEN** local attachments exist and their upload fails under the existing failure policy
- **THEN** the record SHALL remain Pending for retry
- **AND** this change MUST NOT mark it Synced by ignoring that failure
