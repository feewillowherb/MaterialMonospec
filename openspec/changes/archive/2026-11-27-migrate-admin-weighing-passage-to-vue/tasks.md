## 1. Backend Photo Preview & Passage Filter Contracts (repos/UrbanManagement)

- [x] 1.1 Add `PreviewPhotoItemDto` record in `UrbanManagement.Core/Models/` and add `PreviewPhotos` property to `UrbanWeighingRecordOutputDto` and `UrbanPassageListItemDto`
- [x] 1.2 Batch-load up to 2 `PreviewPhotos` per row in `UrbanWeighingRecordAppService.GetListAsync`, `UrbanCheckpointPassageAppService.GetListAsync`, and `UrbanFinishedProductPassageAppService.GetListAsync` (single query per page, no N+1) and add `ProName` & `SyncType` filtering to `UrbanPassageListInputDto` and passage list queries
- [x] 1.3 Add authenticated `GET /api/admin/attachments/{id:guid}` image streaming endpoint in `AdminBffEndpoints` with storage-root containment check and `Cache-Control: private, max-age=3600`

## 2. Shared Vue 3 Verification Components (repos/UrbanManagement/src/UrbanManagement.Admin/client)

- [x] 2.1 Implement `InlinePhotoPair.vue` (2 side-by-side `72×48px` lazy `el-image` thumbnails + `preview-src-list` lightbox + dashed `无图` placeholder)
- [x] 2.2 Implement `DateRangeShortcuts.vue` (`今日` / `近3天` / `近7天` / `本月` + custom range) and `EditHistoryDialog.vue`
- [x] 2.3 Add typed API modules `src/api/weighing.ts` and `src/api/passages.ts`

## 3. Weighing, Approval & Passage Pages

- [x] 3.1 Implement `WeighingRecordView.vue` (`/urban/weighing`) with inline 2-photo scan band, `ProjectRemoteSelect`, `DateRangeShortcuts`, URL Query sync, empty-state quick range buttons, edit history dialog, and sync reset (no `查看照片` button)
- [x] 3.2 Implement `WeighingApprovalView.vue` (`/urban/weighing-approval`) with anomaly/reason filters, inline 2-photo column, edit history, and approval dialog supporting plate/weight correction and native file-input LPR image replacement (no `查看照片` button)
- [x] 3.3 Implement shared `PassageListView.vue` for `/urban/checkpoint-passage` and `/urban/finished-product-passage` with full filtering, pagination, inline 2-photo column, and sync reset (no `查看照片` button, no `1400px` forced width), and wire all 4 routes in `router.ts`

## 4. Verification

- [x] 4.1 Run `npx tsc --noEmit` and `npm run build` in `src/UrbanManagement.Admin/client`
- [x] 4.2 Run `dotnet build` on `UrbanManagement.Admin.csproj`
