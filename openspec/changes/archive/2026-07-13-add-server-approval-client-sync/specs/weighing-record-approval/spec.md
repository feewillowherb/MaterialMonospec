## ADDED Requirements

### Requirement: Client applies server approval sync locally

MaterialClient.Urban SHALL apply server approval sync messages (from SignalR push or pull API) to local weighing records via the Service layer inside a Unit of Work.

#### Scenario: Apply server approval from push

- **WHEN** the client receives a `WeighingRecordApproved` SignalR message for `ClientRecordId`
- **THEN** the Service layer SHALL update local `PlateNumber` and `TotalWeight` to the pushed values
- **AND** SHALL set local `IsAnomaly` to `false` and clear `AnomalyReason`
- **AND** SHALL set local `SyncStatus` to `Synced`
- **AND** SHALL call the server ACK API to set `ClientApprovalAckAt`
- **AND** SHALL publish a local event to refresh the weighing list UI

#### Scenario: Apply server approval from pull on startup

- **WHEN** the application starts or SignalR reconnects
- **AND** the pull API returns pending server approvals for this `ProId`
- **THEN** the client SHALL apply each pending record using the same local application logic as push
- **AND** SHALL ACK each successfully applied record

#### Scenario: Idempotent apply when already synced

- **WHEN** a server approval sync message arrives for a record that is already locally non-anomalous with matching plate and weight
- **THEN** the client MAY skip field updates
- **AND** SHALL still invoke ACK if server `ClientApprovalAckAt` is null

### Requirement: Disable client approval after server approval applied

The Urban weighing list SHALL disable or hide the「审批」action for records that have been updated by server approval sync.

#### Scenario: Approval button disabled after server sync

- **WHEN** local `IsAnomaly == false` because server approval sync was applied
- **THEN** the list row MUST NOT expose an enabled「审批」control

#### Scenario: Approval dialog interrupted by server sync

- **WHEN** the operator has the approval dialog open
- **AND** a server approval sync message arrives for the same `WeighingRecordId`
- **THEN** the system SHALL notify the operator that the record was approved on the server
- **AND** SHALL close the dialog without persisting local approval changes

### Requirement: Relaxed client-server approval conflict

When server approval sync and client local approval overlap, MaterialClient SHALL NOT implement strict conflict arbitration. Either outcome is acceptable.

#### Scenario: Client upload after server approval

- **WHEN** the client later performs local approval and uploads via `ReceiveAsync` after server approval was applied locally
- **THEN** the existing client upload and server upsert flow SHALL proceed without client-side blocking solely due to prior server approval sync
