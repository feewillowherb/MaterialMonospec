## REMOVED Requirements

### Requirement: Role selection

**Reason**: The user wants one project per service (blueprint `07`, D19). What a process hosts is now decided by its service project, not by `Hosting:Roles`.

**Migration**: Remove `Hosting__Roles__*` and `Hosting__AutoMigrate` from deployments; run the matching service image (`urbanmanagement-<service>`). See "Service projects".

### Requirement: Role-gated endpoints

**Reason**: Replaced by service-owned endpoints; code a service does not own is no longer in its assembly.

**Migration**: See "Service-owned endpoints and auto API".

### Requirement: Role-gated background workers

**Reason**: Workers are registered only by the Worker project.

**Migration**: See "Background workers only in the Worker service".

### Requirement: Migration role

**Reason**: Migrations run only in the Migrator project; `Hosting:AutoMigrate` is removed.

**Migration**: See "Migrator service". Run `um-migrator` (or `dotnet run --project src/UrbanManagement.Migrator`) before the other services on a new database.

## ADDED Requirements

### Requirement: Service projects

UrbanManagement SHALL consist of the shared libraries `UrbanManagement.Core` and `UrbanManagement.Hosting`, the gateway `UrbanManagement.Gateway`, and the service projects `UrbanManagement.Ingest`, `UrbanManagement.Attachment`, `UrbanManagement.Realtime`, `UrbanManagement.Admin`, `UrbanManagement.Worker` and `UrbanManagement.Migrator`, all in the UrbanManagement repository. Each service project SHALL have its own entry point and SHALL be published on its own. A service project SHALL NOT reference another service project; contracts used by more than one service SHALL live in Core.

#### Scenario: Published service contains only its own service assembly

- **WHEN** `UrbanManagement.Ingest` is published
- **THEN** the output SHALL contain `UrbanManagement.Ingest.dll`, `UrbanManagement.Hosting.dll` and `UrbanManagement.Core.dll` and no other `UrbanManagement.<Service>.dll`

#### Scenario: Package ownership

- **WHEN** the services are published
- **THEN** `tusdotnet` SHALL be present only in Attachment and the ABP Blazor Server package only in Admin

### Requirement: Service-owned endpoints and auto API

Each service SHALL expose ABP auto API controllers only for its own Core application service types. Ingest SHALL expose `UrbanWeighingRecordAppService`, `UrbanCheckpointPassageAppService` and `UrbanFinishedProductPassageAppService`. Attachment SHALL expose `UrbanAttachmentAppService`. Realtime SHALL expose `ClientLogAppService`. Admin SHALL expose every Core application service except `ClientLogAppService` and `UrbanAuthActivateAppService`. Worker SHALL expose none. Only Attachment SHALL map tus. Only Realtime SHALL map `/hubs/devicestatus` and `/ClientLogs`. Only Admin SHALL map the Blazor hub and the Blazor fallback page. Every web service SHALL map `/health/live` and `/health/ready`.

#### Scenario: Realtime has no admin pages

- **WHEN** `GET /` is sent to the Realtime service
- **THEN** it SHALL answer 404

#### Scenario: Ingest has no tus

- **WHEN** `OPTIONS /api/urban-attachment/tus/` is sent to the Ingest service
- **THEN** it SHALL NOT be answered by a tus endpoint

### Requirement: Background workers only in the Worker service

The system SHALL register `GovSyncBackgroundWorker` and `ClientStatusSnapshotBackgroundWorker` only in the Worker service, each according to its existing switch. Other services SHALL NOT register them, whatever their switches say.

#### Scenario: Sync switch on Ingest

- **WHEN** the Ingest service runs with `BasePlatformSync:Enabled` `true`
- **THEN** `GovSyncBackgroundWorker` SHALL NOT be registered

#### Scenario: Worker with default switches

- **WHEN** the Worker service runs and `ClientStatusSnapshot:Enabled` is not configured
- **THEN** `ClientStatusSnapshotBackgroundWorker` SHALL be registered

### Requirement: Migrator service

The Migrator service SHALL apply pending EF Core migrations and exit with code 0 without serving requests. A migration failure SHALL end the process with a non-zero exit code. No other service SHALL run migrations.

#### Scenario: Migrator succeeds

- **WHEN** the Migrator runs and the database is reachable
- **THEN** it SHALL apply pending migrations and exit with code 0

#### Scenario: Migrator fails

- **WHEN** migration throws
- **THEN** the Migrator SHALL exit with a non-zero code

## MODIFIED Requirements

### Requirement: Client log operations run in the Realtime process

The Realtime service SHALL expose `/internal/client-log/*` (`ClientLogInternalApi.RoutePrefix`) for every `IClientLogAppService` operation except file downloads. A `UserFriendlyException` SHALL be returned as HTTP 400 and a `TimeoutException` as HTTP 504, each with the exception message. In the Admin service, `IClientLogAppService` SHALL forward these operations to `Hosting:RealtimeBaseUrl`, SHALL raise `UserFriendlyException` for 400 and `TimeoutException` for 504 with the returned message, and the Admin service SHALL fail to start when `Hosting:RealtimeBaseUrl` is not set.

#### Scenario: Admin page lists online clients

- **WHEN** the Admin service calls `GetOnlineClientsAsync`
- **THEN** it SHALL send `GET /internal/client-log/online-clients` to the Realtime service and return its result

#### Scenario: Business error keeps its message

- **WHEN** the Realtime service rejects a log list request with `UserFriendlyException("客户端不在线")`
- **THEN** the Admin service SHALL raise `UserFriendlyException` with the same message

#### Scenario: Missing realtime address

- **WHEN** the Admin service starts and `Hosting:RealtimeBaseUrl` is not set
- **THEN** the process SHALL fail at startup
