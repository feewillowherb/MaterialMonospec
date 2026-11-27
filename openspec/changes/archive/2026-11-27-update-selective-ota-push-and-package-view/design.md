# Design: Selective OTA Push and Admin Package Catalog View

## Client Selective Push Gate

- `OtaOptions.AutoCheckEnabled` defaults to `false`.
- `UrbanUpdateBackgroundWorker.DoWorkAsync`:
  - If `!_options.Enabled`, return immediately.
  - If `_options.AutoCheckEnabled`, run `CheckAndDownloadUpdateAsync` then apply if `ReadyToRestart && AutoApplyWhenIdle`.
  - If `!_options.AutoCheckEnabled` (default): **never** call `CheckAndDownloadUpdateAsync`. Only if `updateService.GetStatus().State == UrbanUpdateState.ReadyToRestart && _options.AutoApplyWhenIdle`, call `TryApplyPendingUpdateAsync` so an Admin-pushed update deferred during weighing completes once `OffScale`.

## Admin Package Catalog (`OtaPackageCatalogService`)

- Named records (no tuples):
  - `OtaFeedAssetDto(string PackageId, string Version, string Type, string FileName, long Size, string DownloadUrl)`
  - `OtaFeedCatalogResult(bool IsAvailable, string? LatestVersion, string SetupDownloadUrl, IReadOnlyList<OtaFeedAssetDto> Assets, string? ErrorMessage)`
- Fetch order:
  1. `OtaFeed:InternalBaseUrl` (default `http://um-gateway:8080`) + `/updates/urban/releases.win.json`
  2. Fallback to `fallbackBaseUri` (`NavigationManager.BaseUri`) + `/updates/urban/releases.win.json`
- Download links emitted to browser are always relative (`/updates/urban/{fileName}` and `/updates/urban/MaterialClient.Urban-win-Setup.exe`) so they route cleanly through the browser's Gateway origin.

## Admin Selective Push UX (`ClientUpdates.razor`)

- Card 1: **服务端安装包** — shows latest version badge, direct `Setup.exe` download button, and collapsible/compact asset list (`Version`, `Full/Delta`, formatted size, download link).
- Card 2: **在线客户端（按项目选择性推送）** — search input filtering by `ProjectName` or `ClientId`, version comparison badge (`可升级至 vX.Y.Z` / `已是最新`), per-client「推送更新」button with confirmation modal showing exact `ProjectName` + `ClientId` + target version.
- Advanced options (`FeedUrlOverride`, `ApplyImmediatelyWhenIdle`) collapsed under `<details>` by default.
