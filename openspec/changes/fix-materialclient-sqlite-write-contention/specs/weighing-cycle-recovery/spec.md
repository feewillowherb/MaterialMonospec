## MODIFIED Requirements

### Requirement: Persist and bound finalization recovery

Only products that explicitly enable persistent finalization recovery SHALL persist versioned recovery information in record ExtraProperties and run background recovery. Enabled products SHALL perform no more than three automatic retries after the initial finalization failure, with delays of 5, 30 and 120 seconds. Recovery MUST NOT repeat record creation or consume weighing operation queue slots. Urban and Recycle SHALL retain recovery. SolidWaste and Standard SHALL leave it disabled.

#### Scenario: Product leaves persistent recovery disabled

- **WHEN** SolidWaste or Standard starts attended weighing or creates and finalizes a weighing record
- **THEN** it MUST NOT start background recovery scans or write initial, completion or failure recovery state
- **AND** cycle isolation and ordinary product finalization SHALL remain effective
- **AND** existing recovery metadata SHALL be left intact

#### Scenario: Retries are exhausted

- **WHEN** all three retries fail
- **THEN** recovery SHALL become Exhausted and stop automatic attempts
- **AND** the record and diagnostic information SHALL be retained without blocking subsequent weighing

#### Scenario: Process restarts during recovery

- **WHEN** an enabled product restarts with a versioned unfinished recovery item
- **THEN** it SHALL resume eligible work using the stored identity and remaining retry allowance
- **AND** it MUST NOT reset the attempt count or infer a new cycle for historical records lacking versioned data

#### Scenario: Recovery repeats after a successful side effect

- **WHEN** an attempt is repeated after interruption
- **THEN** finalization SHALL be idempotent for the original record
- **AND** it MUST NOT create another weighing record or requeue an already Synced record merely because recovery repeats
