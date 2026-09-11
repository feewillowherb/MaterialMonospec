## Context

`UrbanPassageListItemDto` already projects `SyncType`, `SyncTime`, and `LargeImageBase64` from AppService list queries. `CheckpointPassage.razor` / `FinishedProductPassage.razor` only render plain `SyncText` and reset sync — no photo action, no sync-time column, no badge classes. `WeighingRecord.razor` shows sync badge + `SyncTime` and opens `WeighingPhotoDialog` (loads LPR + UrbanPhoto via weighing AppService).

## Goals / Non-Goals

**Goals:**

- Parity for **sync presentation** (badge + sync time) and **view photo** on both passage Blazor pages.
- Reuse weighing visual patterns where practical without coupling to weighing-only APIs.

**Non-Goals:**

- Edit-history / anomaly columns (weighing-only).
- Changing reset-sync TEMP rules or Gov workers.
- MaterialClient list UI.

## Decisions

### D1 — Photo dialog uses list DTO base64 (no new photo API)

- **Choice**: Open a passage photo modal with title from plate + captured time; show `LargeImageBase64` already returned by `GetListAsync`. Empty / missing → empty-state message.
- **Alternative**: Fetch photos by id via new AppService method like weighing — deferred; list already loads first large image.
- **Note**: Do not call `IUrbanWeighingRecordAppService` from passage pages.

### D2 — Shared lightweight dialog preferred over forking WeighingPhotoDialog

- **Choice**: Add `PassagePhotoDialog` (or generalize a small image modal) that takes `Visible`, `PlateDisplay`, `CapturedAt`, `ImageBase64`, `OnClose`. Avoid injecting weighing AppService.
- **Alternative**: Reuse `WeighingPhotoDialog` with fake weighing id — wrong dependency, rejected.

### D3 — Sync UI copy weighing badge helpers

- **Choice**: Same CSS classes / Chinese labels as `WeighingRecord.GetSyncTypeBadgeClass` / `GetSyncTypeBadgeText`. Extract shared static helpers only if duplication is painful; otherwise copy the small switch blocks into both pages or a shared razor/static helper in App.
- Add column **同步时间** next to **同步状态**, format `yyyy-MM-dd HH:mm:ss` or `-`.

### D4 — Actions column layout

- Keep「查看照片」always available (opens dialog; empty image handled inside).
- Keep「重置同步」with existing `CanResetSync` TEMP rule.
- Use `table-actions` layout similar to weighing for button grouping.

## Risks / Trade-offs

- [List embeds large base64 for every row] → Existing AppService behavior; do not expand to full gallery in this change. If payload too heavy later, move to on-demand fetch in a follow-up.
- [Dialog UX differs from weighing dual-slot preview] → Accept single large image for passage; document in UI.

## Migration Plan

UI-only + optional shared component; no DB migration.

## Open Questions

- None (sync fields and image already on DTO).
