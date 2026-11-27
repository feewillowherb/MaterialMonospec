## 1. Vue 3 Operations Pages (repos/UrbanManagement/src/UrbanManagement.Admin/client)

- [x] 1.1 Add typed API modules `src/api/clientLogs.ts` and `src/api/clientOta.ts` targeting `/api/admin/client-logs/*` and `/api/admin/client-ota/*`
- [x] 1.2 Implement `ClientLogsView.vue` (`/ops/client-logs`) with wide IPC selector, `?clientId=` preselection, remote log query & pull, persistent alerts, cached directory browser, Blob ZIP download, and delete actions
- [x] 1.3 Implement `ClientUpdatesView.vue` (`/ops/client-updates`) with server OTA catalog table, online 2.0 IPC table, collapsible advanced push options, and push confirmation dialog
- [x] 1.4 Wire `/ops/client-logs` and `/ops/client-updates` in `router.ts`, remove `PendingStageView.vue`, and switch `vite.config.ts` to `base: '/'` and `outDir: '../wwwroot'` (`emptyOutDir: false`)

## 2. Root SPA Cutover & Blazor Removal (repos/UrbanManagement)

- [x] 2.1 Update `AdminSsoAuthentication.cs`, `UrbanManagementAdminModule.cs`, and `UrbanManagement.Admin.csproj` to serve `wwwroot/index.html` at `/` and remove Blazor Server & `IPageFilterStateStore`
- [x] 2.2 Delete legacy `.razor` pages/components, `Pages/_Host.cshtml`, `Services/IPageFilterStateStore.cs`, `Services/WeighingListFilterState.cs`, legacy Blazor models, and legacy `wwwroot/css/`, `wwwroot/js/`, `wwwroot/public/`, `wwwroot/v2/` (preserving `wwwroot/login/*` and `wwwroot/fd-ico.ico`)
- [x] 2.3 Remove `/_blazor` route from `UrbanManagement.Gateway/appsettings.json` and update `deploy/docker/Dockerfile` build comment for Admin client

## 3. Verification

- [x] 3.1 Run `openspec validate migrate-admin-ops-and-remove-blazor --strict`
- [x] 3.2 Run `npx tsc --noEmit && npm run build` in `src/UrbanManagement.Admin/client`
- [x] 3.3 Run `dotnet build` on `UrbanManagement.Admin.csproj` and `UrbanManagement.Gateway.csproj`
