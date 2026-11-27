## 1. Backend Contracts (repos/UrbanManagement)

- [x] 1.1 Add `ProjectIpcStatusAggregator` and named `record` DTOs (`ProjectStatusSummaryDto`, `ProjectIpcSummaryDto`, `ProjectLprItemDto`) in `UrbanManagement.Core/Models/` to aggregate multi-IPC connections and LPR-only device statuses per project (no tuples, no DI registration)
- [x] 1.2 Add unit tests in `UrbanManagement.Core.Tests` verifying single-IPC, multi-IPC (`Online`, `PartialOffline`, `Offline`), multi-LPR (`Online 2/2`, `Abnormal 1/2`), legacy `Unreported`, and exclusion of `Scale`/`Camera`
- [x] 1.3 Add `AdminBffEndpoints` in `UrbanManagement.Admin` exposing authenticated `/api/session`, `/api/admin/projects/status-summary`, `/api/admin/client-logs/*`, and `/api/admin/client-ota/*`, and mount `/v2/{**catchall}` fallback to `wwwroot/v2/index.html` while preserving Blazor fallback

## 2. Vue 3 + Element Plus Workspace Foundation (repos/UrbanManagement/src/UrbanManagement.Admin/client)

- [x] 2.1 Initialize `src/UrbanManagement.Admin/client/` with Vue 3, TypeScript, Vite (`base: '/v2/'`, `outDir: '../wwwroot/v2'`), Vue Router, Element Plus, and design tokens (`styles.css`)
- [x] 2.2 Implement `src/api/http.ts` (401 redirect to `/login?returnUrl=...`) and typed API modules (`session.ts`, `projects.ts`)
- [x] 2.3 Implement `AdminShell.vue` with collapsible dark sidebar (3 root nav groups: 城管 / 资源化 / 工控机运维), topbar (breadcrumb, refresh, user, logout), dynamic `document.title`, and placeholder routes for Stage 2–3 pages
- [x] 2.4 Implement shared `OpsDataTable.vue` (scrollable sticky-header container, all columns resizable via `header-dragend`, `localStorage` persistence + reset) and `ProjectRemoteSelect.vue` (520px+ wide multi-line dropdown popper with fuzzy search)

## 3. Project Management Pages (Urban 5001 & Recycle 5020)

- [x] 3.1 Implement `ProjectListView.vue` shared by `/urban/projects` (5001) and `/recycle/projects` (5020) with status segmented filter, `仅看异常` toggle, keyword search, URL Query sync, narrowed `项目地址`, `工控机` label, inline `抓拍机` status with hover details, `yyyy-MM-dd` `授权过期时间`, and removal of `设备` button/modal
- [x] 3.2 Implement expandable multi-IPC sub-table inside `ProjectListView.vue` showing per-IPC identifier, status, LPR status, app version, last online time, and per-IPC log/update navigation

## 4. Verification

- [x] 4.1 Run `npm install && npm run build` in `repos/UrbanManagement/src/UrbanManagement.Admin/client` and verify output in `wwwroot/v2/`
- [x] 4.2 Run `dotnet build` and `dotnet test` in `repos/UrbanManagement` (Note: `UrbanManagement.Admin` & `UrbanManagement.Core` build cleanly with 0 errors; `UrbanManagement.Core.Tests` has a pre-existing unrelated compile error in `RecyclePersistenceRulesTests.cs:93`)
