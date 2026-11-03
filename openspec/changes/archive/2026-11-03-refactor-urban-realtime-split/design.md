## Context

`ClientLogAppService` keeps its state in process statics fed by `DeviceStatusHub` callbacks (pending log-list requests, file chunk buffers, the cached-file id map). Only the process hosting the hub can serve it. The Blazor page `ClientLogs.razor` is its only in-process caller outside the hub; file downloads already go through `/api/client-log/*`.

## Decisions

### Roles

`Realtime`, `Admin`, `Attachment` are new; `Console` covers `Realtime` + `Admin` (so a single-process or Phase 2 style deployment keeps working). `Ingest` no longer implies tus: tus belongs to `Attachment`.

### Client log forwarding over an internal HTTP API

- Realtime exposes `ClientLogInternalController` at `/internal/client-log/*` (one endpoint per `IClientLogAppService` method except downloads). It answers 404 unless the process hosts `Realtime`. `UserFriendlyException` → 400 and `TimeoutException` → 504, both with body `ClientLogInternalError(Message)`.
- When the process hosts `Admin` but not `Realtime`, `RemoteClientLogAppService` replaces the conventional registration (typed `HttpClient`, base `Hosting:RealtimeBaseUrl`, 30 min timeout for pull-by-date). It maps 400 back to `UserFriendlyException` and 504 to `TimeoutException`, so the page's existing error handling is unchanged. It is `[RemoteService(IsEnabled = false)]`.
- Downloads are not forwarded (`NotSupportedException`): `/api/client-log/download*` is routed to Realtime by the gateway, so the cached path map and files are local there.
- ABP's own Auto API `/api/app/client-log/**` is also routed to Realtime so it never runs against the Admin process's empty state.
- Rejected: ABP dynamic C# client proxies (adds `Volo.Abp.Http.Client`, conventional route coupling); a shared volume (state is in memory, not on disk).

### `/internal/**` is never public

The gateway answers `/internal/**` with 404 before YARP. The API is reachable only on the compose network.

### Attachment stays single-instance; the tus result map stays in memory

tus temporary files live in a local volume and the tus result map is only read after the upload completes on the same process. Moving the map to Redis alone would not make Attachment scalable, so it stays in memory. Ingest has no per-process state and runs two instances (`um-ingest`, `um-ingest-2`, explicit YARP destinations, round robin).

### Deferred: multiple Realtime instances

The hub keeps four static dictionaries (message times, ProId map, log capability registry, file transfers). Multiple instances would need them in Redis plus sticky sessions for SignalR. On one VM this buys no availability; deferred.

## Risks

- A Realtime restart drops in-flight client log pulls (as before) and disconnects clients, which reconnect automatically.
- Memory: two extra app processes (~100 MB each idle); VM headroom is checked by the deploy Graph (`memMinAvailableMb`).
