## MODIFIED Requirements

### Requirement: Repository container definition

The UrbanManagement repository SHALL contain a container definition under `deploy/docker/`: a `Dockerfile` that builds one image per service project from its publish output (`--build-arg SERVICE=<Name>`) on `mcr.microsoft.com/dotnet/aspnet:10.0` running as a non-root user, where only the Worker image also contains the import tool; a `compose.yaml` defining `um-gateway`, `um-migrator`, `um-ingest`, `um-ingest-2`, `um-attachment`, `um-realtime`, `um-admin`, `um-worker`, `mssql` and `redis`, each application service using its own image `urbanmanagement-<service>` with the shared tag `UM_TAG`; and an `.env.example` listing required variables without values. Secrets SHALL NOT be committed. Only `um-gateway` SHALL publish a port to the host. The application services SHALL start only after `um-migrator` has completed successfully. Only `um-worker` SHALL take the sync switches from the environment; the other services SHALL have them fixed to `false`. `um-admin` SHALL set `Hosting:RealtimeBaseUrl` to `um-realtime`.

#### Scenario: Acceptance configuration disables outbound sync

- **WHEN** the stack is started with the acceptance defaults
- **THEN** `BasePlatformSync:Enabled` and `BackgroundServices:Polling` SHALL both be `false` on every service, so that the government sync worker is not registered

#### Scenario: Attachments use the shared directory

- **WHEN** `UM_UPLOADS_HOST_PATH` points to the SMB mount of the IIS `Uploads` directory
- **THEN** every application service SHALL read and write attachments under that directory at `/app/Uploads`, while tus temporary files stay in a local volume mounted only on `um-attachment`

#### Scenario: Migration runs once before the services

- **WHEN** the stack is started
- **THEN** `um-migrator` SHALL apply migrations and exit with code 0 before the application services start, and those services SHALL NOT run migration themselves

#### Scenario: One image per service with one tag

- **WHEN** a release is deployed
- **THEN** seven images `urbanmanagement-{gateway,ingest,attachment,realtime,admin,worker,migrator}` SHALL be built with the same tag, and each application container SHALL contain only its own service assembly
