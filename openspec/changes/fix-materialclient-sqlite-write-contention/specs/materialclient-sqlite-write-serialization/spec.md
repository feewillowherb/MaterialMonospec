## ADDED Requirements

### Requirement: Serialize SolidWaste SQLite business writes

The SolidWaste client SHALL serialize business writes to the same SQLite file within the process. The operation that owns the write transaction SHALL release its turn after transaction commit or rollback and disposal.

#### Scenario: Recovery and stable weighing request overlapping writes

- **WHEN** recovery and stable weighing attempt to write to the same database file
- **THEN** the second operation SHALL wait for the first write transaction to end before starting its own write transaction

#### Scenario: Matching writes kernel and extension records

- **WHEN** automatic matching persists a waybill and its SolidWaste extension
- **THEN** both writes SHALL use the same database connection and transaction
- **AND** a failure before commit SHALL roll back both writes

#### Scenario: Finalization updates the recovery state

- **WHEN** finalization persists a recovery completion or retry state
- **THEN** the state update SHALL participate in the UoW owned by its calling write operation
- **AND** the helper SHALL NOT create a nested independent UoW
