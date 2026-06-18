## 1. UrbanManagement - DTO and Service Interface

- [ ] 1.1 Add `LrpReplacementBase64` and `UrbanPhotoReplacementBase64` nullable string properties to `UrbanWeighingRecordApproveInputDto` in `Core/Models/UrbanWeighingRecordDtos.cs`
- [ ] 1.2 Add `Task<Guid> ReplaceAttachmentAsync(Guid recordId, AttachType attachType, string base64Image)` method signature to `IFileService` interface in `Core/Services/IFileService.cs`

## 2. UrbanManagement - FileService ReplaceAttachmentAsync Implementation

- [ ] 2.1 Implement `ReplaceAttachmentAsync` in `Core/Services/FileService.cs`: query existing `UrbanWeighingRecordAttachment` + `AttachmentFile` rows by `recordId` and `attachType`, save new image via existing `SaveAndCompressImagesAsync`, create new `AttachmentFile` and junction record, then delete old junction + old `AttachmentFile` + attempt old disk file deletion (log warning on failure, do not throw)

## 3. UrbanManagement - ApproveAsync Image Replacement Logic

- [ ] 3.1 In `UrbanWeighingRecordAppService.ApproveAsync`, add conditional calls to `ReplaceAttachmentAsync` when `LrpReplacementBase64` or `UrbanPhotoReplacementBase64` is non-null/non-empty
- [ ] 3.2 Set `EditEntry.IsImagesModified = true` on the new edit entry when any replacement occurred, otherwise `false` (replace the current hardcoded `false`)

## 4. UrbanManagement - Web UI Anomaly Hint

- [ ] 4.1 In `WeighingPhotoPreview.razor`, change the Lrp empty state text from "暂无图片" to "抓拍异常" and add distinct warning styling (e.g. orange/yellow text)

## 5. MaterialClient - Dialog ViewModel Image Replacement

- [ ] 5.1 In `WeighingRecordEditDialogViewModel.cs`, add `[Reactive]` properties `LrpReplacementBase64` and `UrbanPhotoReplacementBase64`
- [ ] 5.2 Add `ReplaceLprCommand` and `ReplaceUrbanPhotoCommand` ReactiveCommands that open a file picker (filtered to image extensions), read the selected file as Base64, update the corresponding `LprPhotoPath`/`CameraPhotoPath` preview, and store the Base64 in the replacement property
- [ ] 5.3 Extend `EditResult` record to include `LrpReplacementBase64?` and `UrbanPhotoReplacementBase64?` fields; populate them in the `Save` command

## 6. MaterialClient - Dialog View UI Changes

- [ ] 6.1 In `WeighingRecordEditDialog.axaml`, add a "替换" button below each photo preview section (Lrp and UrbanPhoto), bound to `ReplaceLprCommand` and `ReplaceUrbanPhotoCommand`
- [ ] 6.2 In `WeighingRecordEditDialog.axaml`, add "抓拍异常" warning text with distinct styling that is visible when `LprPhotoPath` is null/empty, and collapsed when Lpr is present

## 7. MaterialClient - Approval Flow Integration

- [ ] 7.1 In `UrbanAttendedWeighingViewModel.ApproveRecordAsync`, extract replacement Base64 from `EditResult` and pass it through to the server approval call (alongside existing plate/weight data)
- [ ] 7.2 Verify the full flow: open approval dialog → replace image → confirm → secondary confirmation → server receives replacement and processes it → record list refreshes → Lrp empty shows "抓拍异常"
