## Why

Phase 3 split UrbanManagement into processes (`Hosting:Roles`), but every process still runs the same `UrbanManagement.App` assembly and image: all controllers, Blazor pages, tus and hub code ship everywhere, and a role only decides what gets mapped at startup. The user wants a project split — each service its own project and image — inside the same repository (blueprint `docs/2026-11-02-urbanmanagement-docker-mssql-upgrade/07`, decision D19: no extra Git repositories).

## What Changes

- **Remove `UrbanManagement.App`.** Its code moves into:
  - `UrbanManagement.Hosting` (class library): process bootstrap (`UrbanServiceHost`), shared module (JSON, Refit clients, SignalR + Redis backplane, forwarded headers, limits, CORS, health checks, Data Protection), shared pipeline, traffic metering, one shared `appsettings.json` linked into every service.
  - Service projects `UrbanManagement.Ingest`, `.Attachment`, `.Realtime`, `.Admin`, `.Worker`, `.Migrator`, each with its own `Program.cs` and ABP startup module, owning only its controllers / endpoints / packages (tus only in Attachment, Blazor only in Admin).
- **ABP auto API per service**: AppServices stay in Core; each service exposes only its AppService types (`UrbanServicePipeline.ExposeCoreAppServices`). The gateway path table is unchanged and still decides which methods reach which service.
- **Remove `Hosting:Roles` and `Hosting:AutoMigrate`**: background workers are registered only by the Worker project, migrations run only in the Migrator project. `Hosting` keeps `TrustForwardedHeaders` and `RealtimeBaseUrl`.
- **Internal client log contract** (`ClientLogInternalApi`, `ClientLogInternalError`) moves to Core so Admin does not reference Realtime.
- **Containers**: one Dockerfile with `--build-arg SERVICE=<Name>` builds `urbanmanagement-<service>` images (Worker target also carries the import tool); compose uses one image per service with a shared `UM_TAG`.
- **IIS publish scripts removed** (`scripts/publish.ps1` / `.cmd` published `UrbanManagement.App` for IIS, which the Docker cutover retires).
- **Graphs**: `ops/deploy-urban-acceptance` publishes and builds seven images and checks the split structurally (service assembly per container, tus / Blazor / import tool placement).

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `urban-role-hosting`: role switches replaced by service projects; worker and migration ownership; client log forwarding wording.
- `urban-container-deployment`: one image per service.

## Impact

- `repos/UrbanManagement`: `src/UrbanManagement.App` removed; new `Hosting` + six service projects; Core `HostingOptions`, `UrbanManagementCoreModule`, new `Models/ClientLogInternalApi.cs`; `deploy/docker/Dockerfile`, `compose.yaml`; `scripts/publish.*` removed; tests; `AGENTS.md`, `CLAUDE.md`, solution.
- monospec: `ops/deploy-urban-acceptance` Graph; blueprint `07` / `03` / `05`.
- Gateway routes, client paths and the database are unchanged. MaterialClient: no change.
