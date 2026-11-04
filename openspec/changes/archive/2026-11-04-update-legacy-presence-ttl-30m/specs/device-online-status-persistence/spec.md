## ADDED Requirements

### Requirement: Legacy-prefixed live connection TTL is 30 minutes

When UrbanManagement writes or renews a **live** Redis client-connection entry whose `ClientId` starts with `legacy:` (ordinal case-insensitive), the AbsoluteExpiration (live TTL) MUST be **30 minutes** (configurable via `LegacyLiveTtlMinutes`, default 30). This TTL MUST apply on Touch / connected upsert for those ids. ClientIds that do **not** use the `legacy:` prefix MUST continue to use the existing SignalR-derived live TTL (`max(60, ClientTimeoutIntervalSeconds) × 2`). Offline retention TTL is unchanged.

#### Scenario: Legacy Touch uses 30-minute live TTL

- **WHEN** the system Touches or upserts a live connection for `ClientId` = `legacy:{AccessCode}`
- **THEN** the Redis live entry AbsoluteExpiration SHALL be 30 minutes (or the configured `LegacyLiveTtlMinutes` when explicitly set)
- **AND** `IsConnected` SHALL be true for that entry until expiry or an explicit offline upsert

#### Scenario: Non-legacy ClientId keeps SignalR live TTL

- **WHEN** the system Touches or upserts a live connection for a `ClientId` that does not start with `legacy:`
- **THEN** AbsoluteExpiration SHALL follow the existing SignalR live TTL formula
- **AND** SHALL NOT use the Legacy 30-minute TTL

## MODIFIED Requirements

### Requirement: Weighing receive touches live online presence

After a successful `ReceiveAsync` (including Legacy ingest that delegates to `ReceiveAsync`), UrbanManagement MUST Touch live online presence when a usable instance `ClientId` is available, using the same Touch semantics as SignalR (renew or recreate). Legacy clients that have no SignalR SHALL become visible as online through this path alone. For `ClientId` values with the `legacy:` prefix, the live Redis TTL applied by that Touch MUST be the Legacy live TTL (default 30 minutes), not the SignalR short live TTL.

#### Scenario: Legacy Post marks project instance online

- **WHEN** a Legacy `/Api/Post` request is accepted and `ReceiveAsync` succeeds for a registered AccessCode
- **THEN** the system SHALL Touch live online for `ProId` = the resolved project id
- **AND** `ClientId` SHALL be exactly `legacy:{AccessCode}` where `{AccessCode}` is the normalized project access code used for lookup
- **AND** the live Redis entry SHALL use the Legacy live TTL (default 30 minutes)
- **AND** subsequent client-list / project badge aggregation SHALL treat that instance as connected while that Legacy live TTL remains valid

#### Scenario: Modern receive with SubmitMachineCode touches online

- **WHEN** `ReceiveAsync` succeeds and `SubmitMachineCode` is non-empty
- **THEN** the system SHALL Touch live online for that `ProId` with `ClientId` = `SubmitMachineCode`
- **AND** SHALL renew or recreate the live entry as for SignalR Touch
- **AND** SHALL use the SignalR-derived live TTL unless that `ClientId` starts with `legacy:`

#### Scenario: Modern receive without SubmitMachineCode skips presence touch

- **WHEN** `ReceiveAsync` succeeds and `SubmitMachineCode` is null or whitespace
- **THEN** the system SHALL NOT invent a ProId-only live connection row
- **AND** SHALL leave SignalR-based presence unchanged by this receive
