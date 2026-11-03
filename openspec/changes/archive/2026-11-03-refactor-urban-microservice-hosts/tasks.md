Branch: `refactor-urban-microservice-hosts` in monospec and `repos/UrbanManagement` (Mode A).

## 1. UrbanManagement — projects

- [x] 1.1 Add `src/UrbanManagement.Hosting` (library): `UrbanServiceHost`, `UrbanManagementHostingModule`, `UrbanServicePipeline`, readiness check, traffic metering, shared `appsettings.json`, `UrbanService.props`
- [x] 1.2 Add service projects Ingest, Attachment, Realtime, Admin, Worker, Migrator with `Program.cs` + startup module; move controllers / pages / tus / client log forwarding from `UrbanManagement.App` (git mv)
- [x] 1.3 Per-service ABP auto API predicates (`ExposeCoreAppServices`)
- [x] 1.4 Remove `UrbanManagement.App`, IIS `web.config` and `scripts/publish.*`; update solution
- [x] 1.5 Core: `HostingOptions` without `Roles` / `AutoMigrate`; workers no longer registered by `UrbanManagementCoreModule`; `ClientLogInternalApi` / `ClientLogInternalError` in `Core.Models`
- [x] 1.6 Tests: `HostingOptionsTests` for remaining options; `RemoteClientLogAppServiceTests` reference Admin (223 pass)
- [x] 1.7 `AGENTS.md` / `CLAUDE.md` project structure and microservice rules

## 2. UrbanManagement — containers

- [x] 2.1 `deploy/docker/Dockerfile`: `service` / `worker` targets, `SERVICE` build arg
- [x] 2.2 `deploy/docker/compose.yaml`: image per service, no `Hosting__Roles` / `Hosting__AutoMigrate`, gateway from `/app`

## 3. Monospec — Graphs and blueprint

- [x] 3.1 `ops/deploy-urban-acceptance`: publish seven services, build seven images with one tag, structural split checks, wait for Realtime behind the gateway, local secret fallback path
- [x] 3.2 Blueprint `07` review result and status; `03` / `05` references to the single image

## 4. Verification

- [x] 4.1 `dotnet build` (0 errors) and `dotnet test` (223 pass)
- [x] 4.2 `ops/deploy-urban-acceptance`: deploy `2026-11-03T160806` (split checks all pass; failed on a gateway→realtime 502 while Realtime was still booting), verify `2026-11-03T161400` (failed: image count only emitted in deploy mode), both Graph issues fixed in 3.1 → verify `2026-11-03T161446` `pass`
- [x] 4.3 `ops/e2e-urban-phase2` `2026-11-03T161517` `pass`
- [x] 4.4 `ops/urban-cutover` `-Mode check` `2026-11-03T161545` `pass`
- [x] 4.5 Human squash merge into both repositories' `main` (Mode A)
