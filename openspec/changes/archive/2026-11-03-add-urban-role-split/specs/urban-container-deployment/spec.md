## MODIFIED Requirements

### Requirement: Repository container definition

The UrbanManagement repository SHALL contain a container definition under `deploy/docker/`: a `Dockerfile` that packages the published application, the gateway (`/app/gateway`) and the import tool into one image on `mcr.microsoft.com/dotnet/aspnet:10.0` running as a non-root user; a `compose.yaml` defining `um-gateway`, `um-migrator`, `um-ingest`, `um-console`, `um-worker`, `mssql` and `redis`; and an `.env.example` listing required variables without values. Secrets SHALL NOT be committed. Only `um-gateway` SHALL publish a port to the host. `um-ingest`, `um-console` and `um-worker` SHALL start only after `um-migrator` has completed successfully. Only `um-worker` SHALL take the sync switches from the environment; the other roles SHALL have them fixed to `false`.

#### Scenario: Acceptance configuration disables outbound sync

- **WHEN** the stack is started with the acceptance defaults
- **THEN** `BasePlatformSync:Enabled` and `BackgroundServices:Polling` SHALL both be `false` on every role, so that the government sync worker is not registered

#### Scenario: Attachments use the shared directory

- **WHEN** `UM_UPLOADS_HOST_PATH` points to the SMB mount of the IIS `Uploads` directory
- **THEN** `um-ingest`, `um-console` and `um-worker` SHALL read and write attachments under that directory at `/app/Uploads`, while tus temporary files stay in a local volume mounted only on `um-ingest`

#### Scenario: Migration runs once before the roles

- **WHEN** the stack is started
- **THEN** `um-migrator` SHALL apply migrations and exit with code 0 before `um-ingest`, `um-console` and `um-worker` start, and those roles SHALL NOT run migration themselves
