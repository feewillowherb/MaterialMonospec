## MODIFIED Requirements

### Requirement: LastSeenAt refresh without dedicated heartbeat

The system SHALL expose a live-connection Touch path that renews last-seen and Redis live TTL for a `(ProId, ClientId)` instance, and MUST **recreate** a live online entry (`IsConnected = true`) when the live key is missing. Qualifying SignalR `UploadStatus` messages that carry usable `ProId` and `ClientId` MUST invoke this Touch path (not only on first Hub connection mapping). The system MUST NOT introduce a separate heartbeat Hub method. Optional minimum-interval throttle MAY limit how often last-seen timestamps advance, but MUST NOT skip renewing live key TTL on Touch. This capability does **not** require MaterialClient periodic presence republish.

#### Scenario: Status upload refreshes last-seen and live TTL

- **WHEN** an `UploadStatus` message includes known `ProId` and `ClientId`
- **AND** a live connection entry already exists
- **THEN** the system SHALL update that entry's last-seen subject to an optional throttle
- **AND** SHALL renew the live Redis TTL for that connection
- **AND** SHALL NOT require a new Hub method beyond `UploadStatus`

#### Scenario: Status upload recreates live online after TTL expiry

- **WHEN** an `UploadStatus` message includes known `ProId` and `ClientId`
- **AND** the live Redis connection key for that instance is missing (expired or never written)
- **AND** the SignalR connection may still be the same ConnectionId as before expiry
- **THEN** the system SHALL recreate a live online entry with `IsConnected = true`
- **AND** management client-list / project badge queries SHALL report the instance online after the upload

#### Scenario: Missing ClientId does not fall back to ProId-only upsert

- **WHEN** an `UploadStatus` that would register online or device detail lacks a usable `ClientId`
- **THEN** the system SHALL NOT upsert a ProId-only connection or device entry that would violate multi-instance uniqueness
- **AND** SHALL log a warning or error for diagnostics

## ADDED Requirements

### Requirement: Weighing receive touches live online presence

After a successful `ReceiveAsync` (including Legacy ingest that delegates to `ReceiveAsync`), UrbanManagement MUST Touch live online presence when a usable instance `ClientId` is available, using the same Touch semantics as SignalR (renew or recreate). Legacy clients that have no SignalR SHALL become visible as online through this path alone.

#### Scenario: Legacy Post marks project instance online

- **WHEN** a Legacy `/Api/Post` request is accepted and `ReceiveAsync` succeeds for a registered AccessCode
- **THEN** the system SHALL Touch live online for `ProId` = the resolved project id
- **AND** `ClientId` SHALL be exactly `legacy:{AccessCode}` where `{AccessCode}` is the normalized project access code used for lookup
- **AND** subsequent client-list / project badge aggregation SHALL treat that instance as connected while the live TTL remains valid

#### Scenario: Modern receive with SubmitMachineCode touches online

- **WHEN** `ReceiveAsync` succeeds and `SubmitMachineCode` is non-empty
- **THEN** the system SHALL Touch live online for that `ProId` with `ClientId` = `SubmitMachineCode`
- **AND** SHALL renew or recreate the live entry as for SignalR Touch

#### Scenario: Modern receive without SubmitMachineCode skips presence touch

- **WHEN** `ReceiveAsync` succeeds and `SubmitMachineCode` is null or whitespace
- **THEN** the system SHALL NOT invent a ProId-only live connection row
- **AND** SHALL leave SignalR-based presence unchanged by this receive
