## ADDED Requirements

### Requirement: Configurable tus temporary storage

The system SHALL read the tus temporary storage directory from `StorageOptions:TusTempPath`. A relative value SHALL be resolved under the content root; an absolute value SHALL be used as is. When the option is not configured, the directory SHALL be `{ContentRoot}/Uploads/_tus`, identical to the previous hard-coded location.

#### Scenario: Default keeps the previous location

- **WHEN** `StorageOptions:TusTempPath` is not configured
- **THEN** tus uploads SHALL be stored under `{ContentRoot}/Uploads/_tus`

#### Scenario: Container uses a local volume

- **WHEN** `StorageOptions:TusTempPath` is `/app/tus`
- **THEN** tus uploads SHALL be stored under `/app/tus` and nothing SHALL be written to `{ContentRoot}/Uploads/_tus`

### Requirement: Health check endpoints

The system SHALL expose `GET /health/live` and `GET /health/ready` without authentication. `/health/live` SHALL return HTTP 200 whenever the process can serve requests. `/health/ready` SHALL return HTTP 200 only when a connection to the `Default` database succeeds and the attachment storage root directory exists; otherwise it SHALL return HTTP 503. Both endpoints SHALL take precedence over the Blazor fallback route.

#### Scenario: Ready when dependencies are available

- **WHEN** the database accepts connections and the attachment storage root exists
- **THEN** `GET /health/ready` SHALL return HTTP 200

#### Scenario: Not ready when the database is unreachable

- **WHEN** the database connection fails
- **THEN** `GET /health/ready` SHALL return HTTP 503 and `GET /health/live` SHALL still return HTTP 200

### Requirement: Persistent Data Protection keys

When `DataProtection:KeysPath` is configured, the system SHALL persist the ASP.NET Core Data Protection key ring to that directory under the application name `UrbanManagement`, so that keys survive container re-creation. When the option is not configured, the system SHALL keep the framework default key storage.

#### Scenario: Keys survive container re-creation

- **WHEN** `DataProtection:KeysPath` points to a persistent volume and the container is re-created
- **THEN** the application SHALL load the existing key ring from that directory instead of generating a new one

### Requirement: Repository container definition

The UrbanManagement repository SHALL contain a container definition under `deploy/docker/`: a `Dockerfile` that packages the published application on `mcr.microsoft.com/dotnet/aspnet:10.0` and runs as a non-root user, a `compose.yaml` defining `um-app`, `mssql` and `redis` for Phase 1, and an `.env.example` listing required variables without values. Secrets SHALL NOT be committed. `mssql` and `redis` SHALL NOT publish ports to the host.

#### Scenario: Acceptance configuration disables outbound sync

- **WHEN** the stack is started with the acceptance defaults
- **THEN** `BasePlatformSync:Enabled` and `BackgroundServices:Polling` SHALL both be `false`, so that the government sync worker is not registered

#### Scenario: Attachments use the shared directory

- **WHEN** `UM_UPLOADS_HOST_PATH` points to the SMB mount of the IIS `Uploads` directory
- **THEN** `um-app` SHALL read and write attachments under that directory at `/app/Uploads`, while tus temporary files stay in a local volume
