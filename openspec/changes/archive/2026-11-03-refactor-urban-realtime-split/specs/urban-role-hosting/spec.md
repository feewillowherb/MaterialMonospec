## MODIFIED Requirements

### Requirement: Role selection

The system SHALL read the hosting roles from `Hosting:Roles`. The recognised roles SHALL be `Ingest`, `Attachment`, `Realtime`, `Admin`, `Console`, `Worker` and `Migrator`, matched case-insensitively. `Console` SHALL host both `Realtime` and `Admin`. When `Hosting:Roles` is not configured or empty, the process SHALL host all roles, and its behaviour SHALL be identical to the behaviour before role hosting existed.

#### Scenario: Unconfigured process hosts everything

- **WHEN** `Hosting:Roles` is not configured
- **THEN** the process SHALL map tus, the device status hub, the Blazor hub and fallback page, run database migration on startup, and register background workers according to their existing switches

#### Scenario: Role names are case-insensitive

- **WHEN** `Hosting:Roles` contains `ingest`
- **THEN** the process SHALL host the `Ingest` role

#### Scenario: Console covers realtime and admin

- **WHEN** `Hosting:Roles` is `[Console]`
- **THEN** the process SHALL host `Realtime` and `Admin` and SHALL NOT host `Attachment`

### Requirement: Role-gated endpoints

The system SHALL map the tus upload endpoint only when the process hosts the `Attachment` role. The system SHALL map the device status hub (`/hubs/devicestatus`) and the `/ClientLogs` static files only when the process hosts the `Realtime` role, and the Blazor hub and the Blazor fallback page only when the process hosts the `Admin` role. Controllers, ABP conventional API controllers, `/health/live` and `/health/ready` SHALL be mapped for every role.

#### Scenario: Ingest process

- **WHEN** `Hosting:Roles` is `[Ingest]`
- **THEN** neither the tus endpoint nor `/hubs/devicestatus` SHALL be mapped

#### Scenario: Attachment process

- **WHEN** `Hosting:Roles` is `[Attachment]`
- **THEN** `OPTIONS /api/urban-attachment/tus/` SHALL be answered by the tus endpoint and `/hubs/devicestatus` SHALL NOT be mapped

#### Scenario: Realtime process

- **WHEN** `Hosting:Roles` is `[Realtime]`
- **THEN** `/hubs/devicestatus` SHALL be mapped and the Blazor hub, the Blazor fallback page and the tus endpoint SHALL NOT be mapped

#### Scenario: Admin process

- **WHEN** `Hosting:Roles` is `[Admin]`
- **THEN** the Blazor hub and the Blazor fallback page SHALL be mapped and `/hubs/devicestatus` and the tus endpoint SHALL NOT be mapped

### Requirement: Cross-process SignalR delivery

When `SignalR:UseRedisBackplane` is `true` and `Redis:Configuration` is set, the system SHALL use the Redis backplane for SignalR with the channel prefix `UM:signalr`, so that messages sent through `IHubContext<DeviceStatusHub>` in any process reach connections held by the `Realtime` process. When the option is not enabled, SignalR SHALL keep in-process delivery.

#### Scenario: Status pushed from ingest reaches realtime clients

- **WHEN** the backplane is enabled and an `Ingest` or `Admin` process sends a message to a group through `IHubContext<DeviceStatusHub>`
- **THEN** clients connected to the `Realtime` process in that group SHALL receive the message

## ADDED Requirements

### Requirement: Client log operations run in the Realtime process

The system SHALL expose `/internal/client-log/*` for every `IClientLogAppService` operation except file downloads, served only by a process that hosts `Realtime` (other processes SHALL answer 404). A `UserFriendlyException` SHALL be returned as HTTP 400 and a `TimeoutException` as HTTP 504, each with the exception message. When a process hosts `Admin` but not `Realtime`, `IClientLogAppService` SHALL forward these operations to `Hosting:RealtimeBaseUrl`, SHALL raise `UserFriendlyException` for 400 and `TimeoutException` for 504 with the returned message, and the process SHALL fail to start when `Hosting:RealtimeBaseUrl` is not set.

#### Scenario: Admin page lists online clients

- **WHEN** an Admin-only process calls `GetOnlineClientsAsync`
- **THEN** it SHALL send `GET /internal/client-log/online-clients` to the Realtime process and return its result

#### Scenario: Business error keeps its message

- **WHEN** the Realtime process rejects a log list request with `UserFriendlyException("客户端不在线")`
- **THEN** the Admin process SHALL raise `UserFriendlyException` with the same message

#### Scenario: Missing realtime address

- **WHEN** `Hosting:Roles` is `[Admin]` and `Hosting:RealtimeBaseUrl` is not set
- **THEN** the process SHALL fail at startup
