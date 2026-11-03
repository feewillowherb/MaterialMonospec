## Context

Review of blueprint `07` (2026-11-03): the plan is feasible. Phase 3 had already fixed which endpoints each process maps, so the project split is mostly moving code, not redesigning behaviour. Three findings changed the plan:

1. **M1 skipped.** A "thin host still referencing the whole App module" changes nothing a reviewer can check. M2 and M3 are done in one cut, because each service's endpoint set was already known exactly.
2. **M-K3 (auto API leaking into every host).** AppServices live in Core and ABP exposes them from that assembly. Splitting the Application layer is out of scope. Instead, each service registers `ConventionalControllers.Create(CoreAssembly)` with its own type predicate. The same AppService type can still be needed by two services: the gateway sends `urban-weighing-record/receive` to Ingest but the rest of that AppService to Admin. So the predicate is per type, and the gateway path table stays the method-level filter.
3. **Admin must not reference Realtime.** `RemoteClientLogAppService` used `ClientLogInternalController.RoutePrefix`. The contract moves to Core.

## Decisions

### Project layout

| Project | Kind | Owns |
|---------|------|------|
| `UrbanManagement.Core` | library | entities, DbContext, all AppServices, `DeviceStatusHub`, workers' classes, DTOs, cross-service contracts |
| `UrbanManagement.Hosting` | library | `UrbanServiceHost` (bootstrap), `UrbanManagementHostingModule` (shared services), `UrbanServicePipeline` (pipeline + auto API helper), readiness check, traffic metering, shared `appsettings.json` + `UrbanService.props` |
| `UrbanManagement.Ingest` | web | auto API: `UrbanWeighingRecordAppService`, `UrbanCheckpointPassageAppService`, `UrbanFinishedProductPassageAppService`; `UrbanAuthController`, `LegacyApiController` |
| `UrbanManagement.Attachment` | web | auto API: `UrbanAttachmentAppService`; `UrbanAttachmentController`; tus (`tusdotnet` only here) |
| `UrbanManagement.Realtime` | web | auto API: `ClientLogAppService`; `ClientLogController`, `ClientLogInternalController`; `/hubs/devicestatus`, `/ClientLogs` |
| `UrbanManagement.Admin` | web | auto API: every Core AppService except `ClientLogAppService` and `UrbanAuthActivateAppService`; Blazor Server (only here), `RemoteClientLogAppService` |
| `UrbanManagement.Worker` | web (health only) | registers `GovSyncBackgroundWorker` / `ClientStatusSnapshotBackgroundWorker` per their existing switches |
| `UrbanManagement.Migrator` | web bootstrap, no server | applies migrations, exits 0; failure exits 1 |

Service projects reference `Hosting` (and through it Core) via `UrbanService.props`. They never reference each other.

Admin keeps a broad predicate (exclusion list). The gateway's catch-all `/api/**` route goes to Admin, so any AppService added to Core later stays reachable without touching the service modules.

### Configuration

- One `appsettings.json` in `Hosting`, linked into each service output. Under `dotnet run` the content root is the project folder, so `UrbanServiceHost` adds the output copy at the lowest precedence when the content root has none. Containers are unaffected (`/app` is both).
- `appsettings.secret.json` (local, gitignored) moves to `src/UrbanManagement.Hosting/`. It is copied to build output but never published. The deploy Graph's local fallback reads it from there.
- `HostingOptions` keeps `TrustForwardedHeaders` and `RealtimeBaseUrl`. `Roles` and `AutoMigrate` are removed because a process's job is now its project.

### Containers

- One `Dockerfile` with targets `service` and `worker` and build arg `SERVICE`. The entry assembly is `UrbanManagement.${SERVICE}.dll` (exec form through `/bin/sh -c exec`, so dotnet is PID 1). The `worker` target adds `/app/tools/import` because cutover / import runs through the `um-worker` service definition.
- Images: `urbanmanagement-{gateway,ingest,attachment,realtime,admin,worker,migrator}:${UM_TAG}`. One deploy run tags all seven with the same run id (M-K2).
- The gateway image runs from `/app` (no more `working_dir: /app/gateway`).

## Risks / Trade-offs

- **Local development** no longer has an all-in-one process. Run the services needed (Migrator first, Admin needs `Hosting:RealtimeBaseUrl`) or use compose. This was accepted for the user's goal of one project per service.
- **IIS publishing is gone.** Production IIS keeps its current binaries until the Docker cutover. A hotfix for IIS before cutover would have to be built from a commit before this change.
- **Startup ordering:** the gateway's `/health/ready` is answered by Admin, so Realtime can still be booting for a few seconds after the gateway reports ready. Clients reconnect; the deploy Graph waits for hub negotiate before checking.
- **Not in scope:** splitting Core's Application layer, separate databases, multiple Realtime / Attachment instances (M-K4 unchanged), separate Git repositories (D19).
