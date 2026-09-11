## 1. Manual weighing entry

- [ ] 1.1 AppService API to create manual `UrbanWeighingRecord` for a `ProId` with `AnomalyReason=人工录入`, `IsAnomaly=true`, default sync-eligible
- [ ] 1.2 GovSync whitelist: do not skip sync when `AnomalyReason` is `人工录入`
- [ ] 1.3 `ProjectManagement.razor` operation column「添加」+ entry dialog wired to API

## 2. Approval anomaly-reason filter

- [ ] 2.1 Extend weighing list request DTO / `GetListAsync` with `AnomalyReason` filter
- [ ] 2.2 `WeighingApproval.razor` dropdown（全部 + 人工录入 + distinct reasons）bound to filter

## 3. Passage list columns, photo, sync

- [ ] 3.1 Extend `UrbanPassageListItemDto` (+ AppService) with `ProName` and `ShigongUnitName` (batch resolve from GovProject)
- [ ] 3.2 `CheckpointPassage.razor` / `FinishedProductPassage.razor`: columns 施工单位、项目 as first two; sync time + badge;「查看照片」
- [ ] 3.3 Mark `update-urban-passage-um-list-photo-sync` superseded (note in that change or cancel parallel apply)

## 4. Multi-image lightbox

- [ ] 4.1 Shared Blazor multi-image + left-click lightbox component
- [ ] 4.2 Wire weighing photo dialog / approval previews to multi-image + lightbox
- [ ] 4.3 Wire passage photo dialog to the same component

## 5. Verify

- [ ] 5.1 Manual entry creates 人工录入 row and appears in Gov sync when auto-upload default on
- [ ] 5.2 Approval filter by 人工录入 / 全部
- [ ] 5.3 Passage pages: first two columns + photo + sync time; multi-image left-click enlarge on weighing and passage
- [ ] 5.4 `openspec validate add-urban-ops-list-and-manual-entry --strict`
