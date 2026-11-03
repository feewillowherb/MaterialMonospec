# urban-role-hosting Specification

## Purpose
TBD - created by archiving change add-urban-role-split. Update Purpose after archive.
## Requirements
### Requirement: Role selection

The system SHALL read the hosting roles from `Hosting:Roles`. The recognised roles SHALL be `Ingest`, `Console`, `Worker` and `Migrator`, matched case-insensitively. When `Hosting:Roles` is not configured or empty, the process SHALL host all roles, and its behaviour SHALL be identical to the behaviour before this change.

#### Scenario: Unconfigured process hosts everything

- **WHEN** `Hosting:Roles` is not configured
- **THEN** the process SHALL map tus, the device status hub, the Blazor hub and fallback page, run database migration on startup, and register background workers according to their existing switches

#### Scenario: Role names are case-insensitive

- **WHEN** `Hosting:Roles` contains `ingest`
- **THEN** the process SHALL host the `Ingest` role

### Requirement: Role-gated endpoints

The system SHALL map the tus upload endpoint only when the process hosts the `Ingest` role. The system SHALL map the device status hub (`/hubs/devicestatus`), the Blazor hub, the Blazor fallback page and the `/ClientLogs` static files only when the process hosts the `Console` role. Controllers, ABP conventional API controllers, `/health/live` and `/health/ready` SHALL be mapped for every role.

#### Scenario: Ingest process

- **WHEN** `Hosting:Roles` is `[Ingest]`
- **THEN** `OPTIONS /api/urban-attachment/tus/` SHALL be answered by the tus endpoint and `/hubs/devicestatus` SHALL NOT be mapped

#### Scenario: Console process

- **WHEN** `Hosting:Roles` is `[Console]`
- **THEN** `/hubs/devicestatus` and the Blazor pages SHALL be mapped and the tus endpoint SHALL NOT be mapped

### Requirement: Role-gated background workers

The system SHALL register `GovSyncBackgroundWorker` and `ClientStatusSnapshotBackgroundWorker` only when the process hosts the `Worker` role and the existing switch of each worker enables it. When a switch is enabled but the process does not host the `Worker` role, the system SHALL NOT register the worker and SHALL log that it was skipped because of the role.

#### Scenario: Sync switch on a non-worker role

- **WHEN** `Hosting:Roles` is `[Ingest]` and `BasePlatformSync:Enabled` is `true`
- **THEN** `GovSyncBackgroundWorker` SHALL NOT be registered

#### Scenario: Worker role with default switches

- **WHEN** `Hosting:Roles` is `[Worker]` and `ClientStatusSnapshot:Enabled` is not configured
- **THEN** `ClientStatusSnapshotBackgroundWorker` SHALL be registered

### Requirement: Migration role

The system SHALL run database migration on startup when `Hosting:AutoMigrate` is `true` (default) or the process hosts the `Migrator` role, and SHALL skip it otherwise. When `Migrator` is the only configured role, a migration failure SHALL terminate the process with a non-zero exit code, and a successful migration SHALL stop the process with exit code 0 after migration completes.

#### Scenario: Migrator succeeds

- **WHEN** `Hosting:Roles` is `[Migrator]` and the database is reachable
- **THEN** the process SHALL apply pending migrations and exit with code 0

#### Scenario: Migrator fails

- **WHEN** `Hosting:Roles` is `[Migrator]` and migration throws
- **THEN** the process SHALL exit with a non-zero code

#### Scenario: Role process skips migration

- **WHEN** `Hosting:Roles` is `[Console]` and `Hosting:AutoMigrate` is `false`
- **THEN** the process SHALL NOT run database migration on startup

### Requirement: Cross-process SignalR delivery

When `SignalR:UseRedisBackplane` is `true` and `Redis:Configuration` is set, the system SHALL use the Redis backplane for SignalR with the channel prefix `UM:signalr`, so that messages sent through `IHubContext<DeviceStatusHub>` in any process reach connections held by the `Console` process. When the option is not enabled, SignalR SHALL keep in-process delivery.

#### Scenario: Status pushed from ingest reaches console clients

- **WHEN** the backplane is enabled and an `Ingest` process sends a device status message to group `device_{type}` through `IHubContext<DeviceStatusHub>`
- **THEN** clients connected to the `Console` process in that group SHALL receive the message

### Requirement: Forwarded headers behind the gateway

When `Hosting:TrustForwardedHeaders` is `true`, the system SHALL apply `X-Forwarded-For` and `X-Forwarded-Proto` from incoming requests before any other middleware, accepting them from any source. When the option is `false` (default), forwarded headers SHALL be ignored.

#### Scenario: Client address behind the gateway

- **WHEN** `Hosting:TrustForwardedHeaders` is `true` and the gateway forwards a request with `X-Forwarded-For: 10.0.0.5`
- **THEN** `HttpContext.Connection.RemoteIpAddress` SHALL be `10.0.0.5`

