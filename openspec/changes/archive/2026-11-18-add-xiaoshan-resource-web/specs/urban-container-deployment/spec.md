## MODIFIED Requirements

### Requirement: Repository container definition

The UrbanManagement repository SHALL contain a container definition under `deploy/docker/`: a `Dockerfile` that builds one image per service project from its publish output (`--build-arg SERVICE=<Name>`) on `mcr.microsoft.com/dotnet/aspnet:10.0` running as a non-root user, where only the Worker image also contains the import tool; a `compose.yaml` defining `um-gateway`, `um-migrator`, `um-ingest`, `um-ingest-2`, `um-attachment`, `um-realtime`, `um-admin`, `um-xiaoshanresource`, `um-worker`, `mssql` and `redis`, each application service using its own image `urbanmanagement-<service>` with the shared tag `UM_TAG`; and an `.env.example` listing required variables without values. Secrets SHALL NOT be committed. Only `um-gateway` and `um-xiaoshanresource` SHALL publish a port to the host. `um-xiaoshanresource` SHALL publish `UM_XIAOSHAN_PUBLIC_PORT` (default 5334) and SHALL NOT be a destination of `um-gateway`. Its `AdminSso:BaseUrl` SHALL come from `UM_ADMIN_SSO_BASE_URL` and its `AdminSso:WebProductCode` SHALL be 5041. It SHALL NOT receive the UrbanManagement connection string, SHALL NOT mount the shared Hosting `appsettings.Production.json`, and SHALL NOT wait for `um-migrator`. The other application services SHALL start only after `um-migrator` has completed successfully. Only `um-worker` SHALL take the sync switches from the environment; the other services SHALL have them fixed to `false`. `um-admin` SHALL set `Hosting:RealtimeBaseUrl` to `um-realtime`.

#### Scenario: Acceptance configuration disables outbound sync

- **WHEN** the stack is started with the acceptance defaults
- **THEN** `BasePlatformSync:Enabled` and `BackgroundServices:Polling` SHALL both be `false` on every service, so that the government sync worker is not registered

#### Scenario: Attachments use the shared directory

- **WHEN** `UM_UPLOADS_HOST_PATH` points to the SMB mount of the IIS `Uploads` directory
- **THEN** every application service that stores attachments SHALL read and write attachments under that directory at `/app/Uploads`, while tus temporary files stay in a local volume mounted only on `um-attachment`
- **AND** `um-xiaoshanresource` SHALL NOT mount that directory

#### Scenario: Migration runs once before the services

- **WHEN** the stack is started
- **THEN** `um-migrator` SHALL apply migrations and exit with code 0 before the database-backed application services start, and those services SHALL NOT run migration themselves
- **AND** `um-xiaoshanresource` SHALL be allowed to start without waiting for `um-migrator`

#### Scenario: One image per service with one tag

- **WHEN** a release is deployed
- **THEN** eight images `urbanmanagement-{gateway,ingest,attachment,realtime,admin,xiaoshanresource,worker,migrator}` SHALL be built with the same tag, and each application container SHALL contain only its own service assembly

#### Scenario: XiaoShanResource is reached on its own port

- **WHEN** the stack is started on the Docker host
- **THEN** XiaoShanResource SHALL be reachable on host port 5334 unless `UM_XIAOSHAN_PUBLIC_PORT` overrides it
- **AND** `um-gateway` SHALL still publish only `UM_PUBLIC_PORT` and SHALL NOT route to `um-xiaoshanresource`
