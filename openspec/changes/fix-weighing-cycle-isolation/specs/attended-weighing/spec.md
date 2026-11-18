## ADDED Requirements

### Requirement: Isolate asynchronous work by weighing cycle

The system SHALL assign a Guid CycleId when a new weighing cycle starts and SHALL retain that identity for its asynchronous work. Weight and vehicle data SHALL belong to the same cycle. Old-cycle work MUST NOT read vehicle information from, clear caches of, or write the current record identity of a later cycle.

#### Scenario: Capture returns after the original cycle ends

- **WHEN** an old cycle ends before its capture returns and record creation has not started
- **THEN** the old create task SHALL be discarded without creating a record using the next vehicle's data
- **AND** the next cycle SHALL continue normally

#### Scenario: Commit finishes after the next cycle starts

- **WHEN** record creation already started for A and completes after B starts
- **THEN** the committed record SHALL contain only A's captured or sealed cycle data
- **AND** its RecordId MUST NOT become B's current RecordId
- **AND** missing data MAY remain incomplete and SHALL be diagnosed without borrowing B's data

#### Scenario: Late plate within the same cycle

- **WHEN** a valid plate update is accepted within an active cycle under existing plate selection rules
- **THEN** it MAY update that cycle's candidate information
- **AND** after the cycle is sealed, finalization SHALL use its sealed information rather than a later cycle's current plate

### Requirement: Create at most one record per cycle

The system SHALL coordinate concurrent create requests by CycleId so at most one committed weighing record is created for that cycle. A successful record SHALL store its CycleId in ExtraProperties and remain associated with its original cycle.

#### Scenario: Concurrent create requests

- **WHEN** two requests attempt to create a record for the same CycleId concurrently
- **THEN** at most one record SHALL be committed
- **AND** checking recordId once without coordinating the insert MUST NOT be treated as sufficient protection

#### Scenario: Same vehicle weighs again

- **WHEN** a vehicle departs and subsequently begins a new cycle under existing departure rules
- **THEN** the new cycle SHALL have a different CycleId
- **AND** cycle-level deduplication MUST NOT suppress it merely because its plate matches an earlier cycle
