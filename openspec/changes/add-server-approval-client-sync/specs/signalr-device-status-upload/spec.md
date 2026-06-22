## ADDED Requirements

### Requirement: DeviceStatusHub weighing approval push

`DeviceStatusHub` SHALL support server-to-client push of weighing record approval sync messages to connections grouped by `ProId`.

#### Scenario: Hub sends approval message to ProId group

- **WHEN** `ApproveAsync` triggers a server approval sync push for `ProId`
- **THEN** `DeviceStatusHub` SHALL send a `WeighingRecordApproved` message to connections in that ProId group
- **AND** the message payload MUST include `ClientRecordId`, `PlateNumber`, `TotalWeight`, `ServerApprovedAt`, and optional `EditHistoryJson`

#### Scenario: Push does not require client ACK over SignalR

- **WHEN** the server sends a `WeighingRecordApproved` message
- **THEN** client confirmation MUST use the HTTP ACK API per `server-approval-client-sync`
- **AND** SignalR SHALL be used for delivery only

### Requirement: Client subscribes to weighing approval push

`DeviceStatusSignalRClient` SHALL register a handler for `WeighingRecordApproved` messages and forward them to the Urban approval sync application service.

#### Scenario: Handler registered on connect

- **WHEN** `DeviceStatusSignalRClient` establishes a connection
- **THEN** it SHALL register `On("WeighingRecordApproved", ...)`
- **AND** deserialized messages SHALL be passed to the Urban server-approval sync handler

#### Scenario: Reconnect triggers pull fallback

- **WHEN** the SignalR connection transitions to Connected after Reconnecting
- **THEN** the client SHALL invoke the pending server-approval pull API as a fallback
