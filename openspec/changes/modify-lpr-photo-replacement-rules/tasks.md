## 1. Server — EditEntry schema

- [ ] 1.1 Add `bool IsLprAdoptedFromUrbanPhoto` property (default `false`) to `EditEntry` in `repos/UrbanManagement`
- [ ] 1.2 Ensure `EditEntry` JSON serialization includes `IsLprAdoptedFromUrbanPhoto` and deserialization defaults missing values to `false`

## 2. Server — Approval DTO

- [ ] 2.1 Delete `UrbanPhotoReplacementBase64` property from `UrbanWeighingRecordApproveInputDto`
- [ ] 2.2 Add `bool AdoptUrbanPhotoAsLpr` property (default `false`) to `UrbanWeighingRecordApproveInputDto`

## 3. Server — FileService adoption path

- [ ] 3.1 Add `Task<Guid> AdoptUrbanPhotoAsLprAsync(Guid recordId)` to `IFileService`
- [ ] 3.2 Implement `FileService.AdoptUrbanPhotoAsLprAsync` to load the record's current `AttachType.UrbanPhoto` `AttachmentFile` (via injected repository, not from a ViewModel)
- [ ] 3.3 In `AdoptUrbanPhotoAsLprAsync`, read the UrbanPhoto source file from disk and persist a new `AttachmentFile(AttachType.Lrp)` using the existing `SaveAndCompressImagesAsync`-style code path (copy, not move)
- [ ] 3.4 In `AdoptUrbanPhotoAsLprAsync`, insert a new `UrbanWeighingRecordAttachment` junction row linking the new Lrp `AttachmentFile` to the record
- [ ] 3.5 Confirm `AdoptUrbanPhotoAsLprAsync` does NOT delete or modify the original UrbanPhoto `AttachmentFile`, its junction row, or its disk file
- [ ] 3.6 Guard `AdoptUrbanPhotoAsLprAsync`: reject with a business error if the record already has an `AttachType.Lrp` attachment
- [ ] 3.7 Guard `AdoptUrbanPhotoAsLprAsync`: reject with a business error if the record has no `AttachType.UrbanPhoto` attachment
- [ ] 3.8 Mark the implementation with `[UnitOfWork]` so the adoption participates in the caller's transaction

## 4. Server — ApproveAsync orchestration

- [ ] 4.1 Remove the UrbanPhoto replacement branch from `UrbanWeighingRecordAppService.ApproveAsync` (no longer calls `ReplaceAttachmentAsync` for `AttachType.UrbanPhoto`)
- [ ] 4.2 Add mutual-exclusion validation: if both `LrpReplacementBase64` non-empty AND `AdoptUrbanPhotoAsLpr == true`, reject with a business error (or prioritize Lrp replacement — pick one, document at the call site)
- [ ] 4.3 Add adoption branch: when `AdoptUrbanPhotoAsLpr == true`, call `IFileService.AdoptUrbanPhotoAsLprAsync(recordId)`
- [ ] 4.4 Validate adoption preconditions before invoking the FileService: record has no current Lrp attachment AND has an UrbanPhoto attachment
- [ ] 4.5 Update `EditEntry` append logic: set `IsImagesModified = true` only when Lrp replacement occurs
- [ ] 4.6 Update `EditEntry` append logic: set `IsLprAdoptedFromUrbanPhoto = true` when adoption occurs; set it `false` otherwise
- [ ] 4.7 Confirm the approval UnitOfWork wraps attachment work + record update + edit-history append atomically

## 5. Client — EditResult shape

- [ ] 5.1 Delete `UrbanPhotoReplacementBase64` from `EditResult` in `repos/MaterialClient`
- [ ] 5.2 Add `bool AdoptedLpr` (default `false`) to `EditResult`

## 6. Client — Dialog ViewModel

- [ ] 6.1 Delete `ReplaceUrbanPhotoCommand` and any UrbanPhoto-replacement state from `WeighingRecordEditDialogViewModel`
- [ ] 6.2 Add `AdoptUrbanPhotoAsLprCommand` (ReactiveCommand) to `WeighingRecordEditDialogViewModel`
- [ ] 6.3 Expose observable `CanAdoptUrbanPhotoAsLpr` that is `true` only when `LprPhotoPath` is null/empty AND `CameraPhotoPath` is non-empty; bind command enablement to it
- [ ] 6.4 Implement `AdoptUrbanPhotoAsLprCommand` execution: read the UrbanPhoto source file, update the Lrp preview from those bytes, clear the 抓拍异常 indicator on the Lrp section, set `EditResult.AdoptedLpr = true`, and clear any staged `EditResult.LrpReplacementBase64`
- [ ] 6.5 Ensure `ReplaceLrpCommand` execution clears `EditResult.AdoptedLpr` (mutual exclusion at the ViewModel level)
- [ ] 6.6 Optionally expose a 取消采纳 affordance that reverts `EditResult.AdoptedLpr` to `false` and restores the Lrp placeholder + 抓拍异常 indicator

## 7. Client — Dialog View

- [ ] 7.1 Remove the UrbanPhoto preview section's 替换 button and its command binding from `WeighingRecordEditDialog.axaml`
- [ ] 7.2 Add an「采纳为车牌照」button to the Lrp preview section, bound to `AdoptUrbanPhotoAsLprCommand`
- [ ] 7.3 Bind the「采纳为车牌照」button's `IsVisible` to `CanAdoptUrbanPhotoAsLpr` so it is hidden when Lpr is non-empty or UrbanPhoto is absent
- [ ] 7.4 Verify the UrbanPhoto preview section continues to render the image and supports click-to-open `ImageViewerWindow`, but exposes no replacement affordance

## 8. Client — Approval coordinator

- [ ] 8.1 Update `UrbanAttendedWeighingViewModel.ApproveRecordAsync` to stop forwarding `UrbanPhotoReplacementBase64`
- [ ] 8.2 Update `ApproveRecordAsync` to forward `EditResult.AdoptedLpr` as `AdoptUrbanPhotoAsLpr` on `UrbanWeighingRecordApproveInputDto`
- [ ] 8.3 Confirm `LrpReplacementBase64` is still forwarded from `EditResult` to the DTO unchanged

## 9. Cross-cutting — lockstep verification

- [ ] 9.1 Manually verify the client approval dialog no longer offers UrbanPhoto 替换
- [ ] 9.2 Manually verify the「采纳为车牌照」button appears only when Lpr is empty and UrbanPhoto is present
- [ ] 9.3 Manually verify an approval that stages adoption produces a new Lrp attachment and leaves the UrbanPhoto attachment intact on the server
- [ ] 9.4 Manually verify an approval with both Lrp replacement and adoption staged is rejected by the server
- [ ] 9.5 Manually verify the new `EditEntry.IsLprAdoptedFromUrbanPhoto` flag is persisted as `true` only when adoption occurs
- [ ] 9.6 Confirm historical `EditEntry` JSON without `IsLprAdoptedFromUrbanPhoto` deserializes cleanly (field defaults to `false`)
