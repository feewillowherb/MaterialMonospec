## Why

Phase 2 split UrbanManagement into `um-ingest` / `um-console` / `um-worker` behind the YARP gateway. `um-console` still mixes the long-lived device status hub (MaterialClient.Urban connections, client log pull state) with the Blazor admin UI, and `um-ingest` still owns tus uploads, so neither can be restarted or scaled on its own. Phase 3 of the blueprint (`docs/2026-11-02-urbanmanagement-docker-mssql-upgrade/03` §8) finishes the split.

## What Changes

- **New roles** `Realtime` (device status hub, `/ClientLogs` files, client log state), `Admin` (Blazor UI) and `Attachment` (tus). `Console` stays as an alias for `Realtime` + `Admin`. `Ingest` no longer maps tus.
- **Client log forwarding**: an `Admin` process without `Realtime` replaces `IClientLogAppService` with `RemoteClientLogAppService`, which calls the new container-network API `/internal/client-log/*` on the Realtime process (`Hosting:RealtimeBaseUrl`). Downloads stay on `/api/client-log/*`, which the gateway routes to Realtime.
- **Gateway**: clusters `ingest` (2 destinations, round robin), `attachment`, `realtime`, `admin`; hub and client log routes (including `/api/app/client-log/**`) go to realtime, Blazor / API / fallback go to admin, attachment routes go to attachment. The gateway answers `/internal/**` with 404.
- **Compose**: `um-console` is replaced by `um-realtime` and `um-admin`; new `um-attachment` (owns the tus volume) and `um-ingest-2`.
- **Graphs**: `ops/deploy-urban-acceptance` and `ops/e2e-urban-phase2` check the new topology.
- **Deferred**: multiple Realtime instances (hub statics in Redis + sticky sessions) and multiple Attachment instances (tus files and result map are local). A single VM gains no availability from them.

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `urban-role-hosting`: role set, role-gated endpoints, client log forwarding.
- `urban-gateway`: route table and clusters, `/internal/**` refused.
- `urban-container-deployment`: compose services.

## Impact

- `repos/UrbanManagement`: `HostingOptions`, `UrbanManagementAppModule`, new `ClientLogInternalController` and `RemoteClientLogAppService`, gateway `Program.cs` / `appsettings.json`, `deploy/docker/compose.yaml`, tests.
- monospec: two ops Graphs, blueprint `03` / `05`.
- MaterialClient: no change; client paths are unchanged.
