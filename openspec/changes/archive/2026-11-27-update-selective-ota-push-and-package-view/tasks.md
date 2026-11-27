# Tasks: update-selective-ota-push-and-package-view

## 1. MaterialClient
- [x] 1.1 Add `AutoCheckEnabled` (default `false`) to `OtaOptions` and update `UrbanUpdateBackgroundWorker` so default mode never polls for new releases automatically and only applies already-pushed `ReadyToRestart` updates when idle

## 2. UrbanManagement.Admin
- [x] 2.1 Implement `IOtaPackageCatalogService` / `OtaPackageCatalogService` in `UrbanManagement.Admin/Services/` to fetch `/updates/urban/releases.win.json` (via `um-gateway:8080` with `BaseUri` fallback)
- [x] 2.2 Redesign `ClientUpdates.razor` with Server Package Catalog card (`Setup.exe` download + Full/Delta table), project/client filter, version diff badges, single-client push confirmation modal, and collapsible advanced options

## 3. Verification
- [x] 3.1 Run `openspec validate update-selective-ota-push-and-package-view --strict`, build `MaterialClient.Urban` + `UrbanManagement.Admin`, and run OTA unit tests
