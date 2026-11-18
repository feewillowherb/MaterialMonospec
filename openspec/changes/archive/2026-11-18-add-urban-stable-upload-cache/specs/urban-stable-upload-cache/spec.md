## ADDED Requirements

### Requirement: Urban stable-upload switch defaults off

The system MUST add `EnableUploadOnStable` to `WeighingConfiguration`, persisted with the existing weighing configuration JSON. A new instance and a stored JSON object that omits the property MUST both yield `false`. The settings window MUST show a toggle labeled 「稳定后上传」 only on the Urban host. Saving settings MUST persist the chosen value. Non-Urban hosts MUST ignore `true` and MUST keep the existing create and off-scale upload timing.

#### Scenario: Default is off

- **WHEN** a new `WeighingConfiguration` is created without setting `EnableUploadOnStable`
- **THEN** `EnableUploadOnStable` MUST be `false`

#### Scenario: Legacy JSON omits the property

- **WHEN** stored weighing configuration JSON has no `EnableUploadOnStable` field
- **THEN** the loaded value MUST be `false`

#### Scenario: Urban host can persist the toggle

- **WHEN** the Urban host settings window turns on 「稳定后上传」 and the user saves
- **THEN** the stored configuration MUST contain `EnableUploadOnStable = true`

#### Scenario: Non-Urban host does not apply the flag

- **WHEN** the host is not the Urban weighing path and stored `EnableUploadOnStable` is `true`
- **THEN** the system MUST NOT create a produced-plate hold
- **AND** MUST NOT promote `WeighingInProgress` to `Pending` on weight stabilized
- **AND** MUST NOT release the open weighing record at 900 seconds

### Requirement: Produced-plate hold records the create snapshot

When `EnableUploadOnStable` is `true` on the Urban weighing path and a weighing record is created on `WeightStabilized`, the system MUST keep an in-memory produced-plate hold for that record. The hold plate MUST be the `PlateNumber` stored on that new record, including an empty plate. The hold clock MUST start at that creation and MUST NOT move because a later stable edge, a later plate recognition, or a plate rewrite occurs. The hold MUST NOT be written to the database.

#### Scenario: Hold uses the plate saved at create

- **WHEN** Urban stable upload is on and weight stabilization creates a record whose saved plate is `A`
- **THEN** the in-memory hold MUST record plate `A` and that record id
- **AND** a plate recognition that arrives after the create MUST NOT change the hold plate

#### Scenario: Empty snapshot is a hold plate

- **WHEN** Urban stable upload is on and the created record has an empty plate
- **THEN** the hold plate MUST be empty

#### Scenario: Restart is out of scope

- **WHEN** the process stops
- **THEN** the system MUST NOT reload produced-plate holds from storage

### Requirement: Same snapshot plate does not create another record while the hold is live

While Urban stable upload is on and a produced-plate hold is younger than 900 seconds, a new create whose snapshot plate is the same ordinal string as that hold MUST NOT insert another weighing record. A different snapshot plate MUST NOT be treated as a hold hit. Clearing the hold is not required to delete the existing `WeighingRecord` or uploaded data.

#### Scenario: Same plate is refused

- **WHEN** a live hold has plate `A` and a later create would snapshot plate `A` before the hold is 900 seconds old and before off-scale
- **THEN** the system MUST NOT insert a second weighing record for that attempt

#### Scenario: Different plate is not a hold hit

- **WHEN** a live hold has plate `A` and a create snapshots plate `B`
- **THEN** the produced-plate hold MUST NOT reject that create because of plate `A`

### Requirement: Off-scale clears every produced-plate hold

When status enters `OffScale` because weight is less than `WeighingConfiguration.MinWeightThreshold` from `WaitingForStability`, `WeightStabilized`, or `WaitingForDeparture`, the system MUST remove every in-memory produced-plate hold. Weight equal to `MinWeightThreshold` MUST NOT clear the holds. The clear MUST NOT delete weighing records and MUST NOT delete already uploaded data. The existing off-scale plate rewrite and selection-cache clear remain in effect.

#### Scenario: Drop below threshold clears all holds

- **WHEN** one or more produced-plate holds exist and weight changes from above `MinWeightThreshold` to below it while status is `WaitingForStability`, `WeightStabilized`, or `WaitingForDeparture`
- **THEN** every produced-plate hold MUST be removed
- **AND** the persisted weighing record MUST still exist

#### Scenario: Equal to threshold keeps the hold

- **WHEN** a produced-plate hold exists and the sampled weight equals `MinWeightThreshold`
- **THEN** the hold MUST remain

#### Scenario: Same plate may create again after off-scale

- **WHEN** off-scale has cleared the holds and a later cycle stabilizes with the same plate
- **THEN** the system MUST allow one new weighing record for that new cycle

### Requirement: Fifteen-minute fallback allows one later record

When Urban stable upload is on and a produced-plate hold reaches 900 seconds without an off-scale clear, the system MUST remove every produced-plate hold, clear the open weighing record id, and set status to `WaitingForStability`. The system MUST NOT enter `OffScale` only because the 900 seconds elapsed. The next stable create MAY insert one new weighing record and MUST then hold that new record. The fallback MUST NOT insert a new record on every stability sample.

#### Scenario: Fallback releases the open cycle

- **WHEN** Urban stable upload is on, a hold was created 900 seconds ago, and weight has stayed greater than or equal to `MinWeightThreshold`
- **THEN** the produced-plate holds MUST be cleared
- **AND** the open record id MUST be cleared
- **AND** status MUST be `WaitingForStability`

#### Scenario: One new record after fallback

- **WHEN** the 900-second fallback has released the cycle and the scale is then stable
- **THEN** the system MUST create at most one new weighing record before a new hold or an off-scale clear applies
- **AND** MUST NOT create another record on the following sample while that new record is still open and the weight remains above `MinWeightThreshold`

#### Scenario: Later stable edges do not restart the clock

- **WHEN** further stable edges occur before the original hold reaches 900 seconds
- **THEN** the fallback deadline MUST remain the original hold creation time plus 900 seconds
