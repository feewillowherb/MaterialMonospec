## 1. UrbanManagement (branch `refactor-urban-realtime-split`)

- [x] 1.1 `HostingRoles`: add `Realtime`, `Admin`, `Attachment`; `Console` covers `Realtime` + `Admin`; `HostingOptions.RealtimeBaseUrl`, `ForwardsClientLogsToRealtime`
- [x] 1.2 `UrbanManagementAppModule`: hub + `/ClientLogs` on Realtime, Blazor on Admin, tus on Attachment; register `RemoteClientLogAppService` when Admin runs without Realtime
- [x] 1.3 `ClientLogInternalController` (`/internal/client-log/*`, Realtime only) and `RemoteClientLogAppService`
- [x] 1.4 Gateway: clusters `ingest` (x2) / `attachment` / `realtime` / `admin`, route `/api/app/client-log/**`, refuse `/internal/**`
- [x] 1.5 Compose: `um-ingest-2`, `um-attachment`, `um-realtime`, `um-admin` (replaces `um-console`)
- [x] 1.6 Tests: role coverage, remote client log JSON / error mapping

## 2. monospec

- [x] 2.1 `ops/deploy-urban-acceptance`: six roles, routing and internal API checks
- [x] 2.2 `ops/e2e-urban-phase2`: push evidence on admin / realtime
- [x] 2.3 Deploy to the VM and run both Graphs
- [x] 2.4 Blueprint `03` §8 and `05` write-back
