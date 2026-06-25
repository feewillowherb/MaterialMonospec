# server-approval-client-sync Specification

## Purpose
TBD - created by archiving change add-server-approval-client-sync. Update Purpose after archive.
## Requirements
### Requirement: Server approval sync state timestamps

`UrbanWeighingRecord` SHALL include nullable `ServerApprovedAt` and `ClientApprovalAckAt` datetime fields. `ServerApprovedAt` SHALL be set when Web `ApproveAsync` succeeds. `ClientApprovalAckAt` SHALL be set when MaterialClient confirms it has applied the server approval to local storage.

#### Scenario: Pending client sync derived state

- **WHEN** a record has `ServerApprovedAt` not null and `ClientApprovalAckAt` is null
- **THEN** the record SHALL be considered pending server-approval downstream sync to the client

#### Scenario: Sync complete derived state

- **WHEN** a record has both `ServerApprovedAt` and `ClientApprovalAckAt` not null
- **THEN** the record SHALL be considered fully acknowledged by the client for server approval sync

### Requirement: SignalR push on Web approval success

After `ApproveAsync` persists successfully, UrbanManagement SHALL attempt to push a weighing-record-approved message to MaterialClient connections associated with the record's `ProId`.

#### Scenario: Push after successful ApproveAsync

- **WHEN** `ApproveAsync` completes successfully for a record with `ClientRecordId` and `ProId`
- **THEN** the system SHALL set `ServerApprovedAt` to the approval timestamp
- **AND** SHALL leave `ClientApprovalAckAt` null
- **AND** SHALL send a SignalR message to the target ProId client group containing `ClientRecordId`, `PlateNumber`, `TotalWeight`, `ServerApprovedAt`, and optional `EditHistoryJson`

#### Scenario: Push failure does not roll back approval

- **WHEN** SignalR push fails or no client is online
- **THEN** `ApproveAsync` MUST still succeed with `ServerApprovedAt` set
- **AND** the record MUST remain eligible for client pull sync

### Requirement: Client pull API for pending server approvals

UrbanManagement SHALL expose an API for MaterialClient to fetch records where `ServerApprovedAt != null` and `ClientApprovalAckAt == null` for the authenticated project's `ProId`.

#### Scenario: Pull returns pending records

- **WHEN** MaterialClient calls the pending server-approval sync API for its `ProId`
- **THEN** the system SHALL return all matching records with `ClientRecordId`, `PlateNumber`, `TotalWeight`, `ServerApprovedAt`, and optional `EditHistoryJson`

#### Scenario: Pull on reconnect

- **WHEN** MaterialClient SignalR reconnects or application starts
- **THEN** the client SHOULD invoke the pull API to apply any pending server approvals

### Requirement: Client ACK API

UrbanManagement SHALL expose `AckApprovalSyncAsync` (or equivalent conventional route) accepting `ClientRecordId`. The API SHALL set `ClientApprovalAckAt` when the client confirms local application.

#### Scenario: Successful ACK

- **WHEN** `AckApprovalSyncAsync` is called with a valid `ClientRecordId`
- **AND** the record has `ServerApprovedAt` not null
- **THEN** `ClientApprovalAckAt` SHALL be set to the current UTC timestamp
- **AND** the API SHALL return success

#### Scenario: ACK without server approval

- **WHEN** `AckApprovalSyncAsync` is called for a record with `ServerApprovedAt` null
- **THEN** the API SHALL return a business error
- **AND** MUST NOT set `ClientApprovalAckAt`

#### Scenario: Idempotent ACK

- **WHEN** `AckApprovalSyncAsync` is called and `ClientApprovalAckAt` is already set
- **THEN** the API SHALL return success without error

### Requirement: Relaxed conflict policy

When server approval sync and client-side approval overlap in time, the system SHALL NOT enforce strict conflict resolution. Any final persisted state from either endpoint is acceptable.

#### Scenario: Client re-upload after server approval

- **WHEN** the server record has `ServerApprovedAt` set and `IsAnomaly == false`
- **AND** the client later uploads a different payload via `ReceiveAsync` for the same `ClientRecordId`
- **THEN** `ReceiveAsync` SHALL apply the upsert per existing rules
- **AND** MUST NOT return HTTP 409 solely because server approval occurred earlier

#### Scenario: Client approval after server push applied

- **WHEN** the client has already applied server approval locally (`IsAnomaly == false`)
- **AND** the operator attempts local approval again
- **THEN** the client UI SHALL disable or block the approval action for that row
- **AND** if local approval somehow proceeds, `ReceiveAsync` upsert remains permitted without strict arbitration

