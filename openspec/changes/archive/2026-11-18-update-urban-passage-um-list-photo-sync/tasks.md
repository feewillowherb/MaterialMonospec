## 1. Shared UI pieces (UrbanManagement.App)

- [ ] 1.1 Add passage photo dialog component (parameters: Visible, plate, capturedAt, imageBase64, OnClose) with empty-state when no image
- [ ] 1.2 Optionally extract shared sync badge class/text helpers used by weighing + passage pages (only if needed to avoid drift)

## 2. CheckpointPassage.razor

- [ ] 2.1 Add 同步时间 column; render SyncType with weighing-aligned badge classes/labels
- [ ] 2.2 Add「查看照片」action wired to dialog; keep existing 重置同步

## 3. FinishedProductPassage.razor

- [ ] 3.1 Same sync columns/badges as checkpoint
- [ ] 3.2 Same「查看照片」+ dialog wiring; keep 重置同步

## 4. Verify

- [ ] 4.1 Manual: both pages show sync time and badges; photo dialog opens with image and empty-state
- [ ] 4.2 `openspec validate update-urban-passage-um-list-photo-sync --strict`
