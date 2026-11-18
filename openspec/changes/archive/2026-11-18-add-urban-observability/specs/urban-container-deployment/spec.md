## MODIFIED Requirements

### Requirement: Repository container definition

The UrbanManagement repository SHALL contain a container definition under `deploy/docker/`: a `Dockerfile` that builds one image per service project from its publish output (`--build-arg SERVICE=<Name>`) on `mcr.microsoft.com/dotnet/aspnet:10.0` running as a non-root user, where only the Worker image also contains the import tool; a `compose.yaml` defining `um-gateway`, `um-migrator`, `um-ingest`, `um-ingest-2`, `um-attachment`, `um-realtime`, `um-admin`, `um-worker`, `mssql`, `redis`, `otel-collector` and `otel-dashboard`, each application service using its own image `urbanmanagement-<service>` with the shared tag `UM_TAG`; and an `.env.example` listing required variables without values. `otel-collector` and `otel-dashboard` SHALL use their upstream images rather than the service Dockerfile. Secrets SHALL NOT be committed. `um-gateway` SHALL publish `UM_PUBLIC_PORT`. `otel-dashboard` SHALL publish `UM_OTEL_DASHBOARD_PORT` (default 18888) on `UM_OTEL_DASHBOARD_BIND` (default `0.0.0.0`). `otel-collector` SHALL NOT publish a host port. The application services SHALL start only after `um-migrator` has completed successfully. `otel-collector` and `otel-dashboard` SHALL be allowed to start without waiting for `um-migrator`. Only `um-worker` SHALL take the sync switches from the environment; the other services SHALL have them fixed to `false`. `um-admin` SHALL set `Hosting:RealtimeBaseUrl` to `um-realtime`. Application services that export telemetry SHALL set `OTEL_EXPORTER_OTLP_ENDPOINT` to `http://otel-collector:4318`.

#### Scenario: Acceptance configuration disables outbound sync

- **WHEN** the stack is started with the acceptance defaults
- **THEN** `BasePlatformSync:Enabled` and `BackgroundServices:Polling` SHALL both be `false` on every service, so that the government sync worker is not registered

#### Scenario: Attachments use the shared directory

- **WHEN** `UM_UPLOADS_HOST_PATH` points to the SMB mount of the IIS `Uploads` directory
- **THEN** every application service that stores attachments SHALL read and write attachments under that directory at `/app/Uploads`, while tus temporary files stay in a local volume mounted only on `um-attachment`
- **AND** `otel-collector` and `otel-dashboard` SHALL NOT mount that directory

#### Scenario: Migration runs once before the services

- **WHEN** the stack is started
- **THEN** `um-migrator` SHALL apply migrations and exit with code 0 before the database-backed application services start, and those services SHALL NOT run migration themselves
- **AND** `otel-collector` and `otel-dashboard` SHALL be allowed to start without waiting for `um-migrator`

#### Scenario: One image per service with one tag

- **WHEN** a release is deployed
- **THEN** the service images `urbanmanagement-{gateway,ingest,attachment,realtime,admin,worker,migrator}` SHALL be built with the same tag, and each application container SHALL contain only its own service assembly
- **AND** `otel-collector` and `otel-dashboard` SHALL run from their upstream images

#### Scenario: Observability endpoints are separate from the gateway

- **WHEN** the stack is started with the default dashboard settings
- **THEN** the dashboard UI SHALL be published on host port 18888
- **AND** the collector's OTLP port SHALL NOT be published on the host
