## 1. Git (Mode A)

- [x] 1.1 Before first code edit: create and checkout branch `update-urban-passage-client-upload-reconcile` from trunk in MaterialMonospec and MaterialClient

## 2. MaterialClient — passage sync model

- [x] 2.1 Add `SyncStatus`, `RetryCount`, `LastErrorTime`, `SubmitMachineCode` on `UrbanPassageRecord` with type-owned `MarkSynced` / `MarkUploadFailed` / `AssignSubmitMachineCode`
- [x] 2.2 UrbanDbContext migration + index on `SyncStatus`; new rows from LPR default `Pending`
- [x] 2.3 Extend `IUrbanPassageRecordService` with `GetPendingForUploadAsync`, `MarkSyncedAsync`, `MarkUploadFailedAsync`

## 3. MaterialClient — unified upload API

- [x] 3.1 Add `UrbanPassageSubmitDto` record with static `FromPassage`; add `UrbanPassageReceiveResult`
- [x] 3.2 Add Refit methods `ReceiveCheckpointPassageAsync` and `ReceiveFinishedProductPassageAsync` on `IUrbanManagementApi`
- [x] 3.3 Implement `IUrbanAttachmentSyncService.UploadPassageAttachmentsAsync` (large/small attachment ids, multipart default)
- [x] 3.4 Implement `IUrbanPassageUploadService.SubmitPassageRecordAsync` — attachments then receive; fork by `PassageSource`

## 4. MaterialClient — triggers

- [x] 4.1 Extend `PollingBackgroundService` to upload pending passage rows in the same cycle as weighing
- [x] 4.2 Add `UrbanPassageRecordCreatedEventHandler` for immediate upload attempt (non-blocking; polling fallback)

## 5. MaterialClient — verify

- [x] 5.1 Build `MaterialClient.Urban` with `-o .build-verify`
- [x] 5.2 Manual or unit test: checkpoint + finished-product pending rows call correct UM receive paths (no Gov HTTP)

## 6. Pipeline — urban-passage-um-reconcile ClientUpload

- [x] 6.1 Add `scripts/Start-UrbanForReconcile.ps1` — license seed, `UrbanManagement__BaseUrl`, `MinimalWebHost__EnableOnStartup`, optional `Urban__UploadPollingPeriodMs`
- [x] 6.2 Refactor `Invoke-UrbanPassageUmReconcile.ps1` — default `-Mode ClientUpload`; probe → wait upload → GET UM lists; demote Bridge
- [x] 6.3 Update `pipeline.md`, `design-brief.md`, `config.yaml` reconcile modes and L1 criteria for client upload
- [x] 6.4 Cook ClientUpload locally (UM + Urban running); L0–L2 pass; then set `graph.status: active` in config and `pipelines/AGENTS.md`

## 7. OpenSpec hygiene

- [x] 7.1 Mark `add-urbanmanagement-passage-xiaoshan-upload` tasks 7.1–7.2 complete when equivalent work is verified (or note superseded by this change)
- [x] 7.2 `openspec validate update-urban-passage-client-upload-reconcile --strict`
