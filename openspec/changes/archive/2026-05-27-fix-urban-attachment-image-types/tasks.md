## 1. 枚举与路径工具（MaterialClient.Common）

- [x] 1.1 在 `AttachType.cs` 新增 `UrbanPhoto = 6` 及 Description
- [x] 1.2 更新 `AttachmentPathUtils.GetBasePath`：`Lrp` → `Lrp`，`UrbanPhoto` → `PhotoUrban`，其余保持现有逻辑
- [x] 1.3 确认 `GetLocalStorageAbsolutePath` / OSS 相关方法对 `UrbanPhoto`、`Lrp` 行为正确

## 2. 称重周期 LRP 路径跟踪

- [x] 2.1 在 `WeighingStateManager` 增加当前周期 `LrpImagePath` 的 set/get，并在 `ResetCycle` 清空
- [x] 2.2 在 `AttendedWeighingService` 订阅 `LicensePlateRecognizedEventData` 时，若有 `LrpImagePath` 则写入 StateManager

## 3. 抓拍与落库（MaterialClient.Common）

- [x] 3.1 `WeighingCaptureService.CaptureAllCamerasAsync`：UrbanMode 使用 `AttachType.UrbanPhoto` 作为存储路径
- [x] 3.2 `WeighingRecordService.SaveCapturePhotosAsync`：UrbanMode 使用 `UrbanPhoto`，否则 `UnmatchedEntryPhoto`
- [x] 3.3 `WeighingRecordService.CreateWeighingRecordAsync`：UrbanMode 且存在周期内 LRP 路径时，创建 `AttachType.Lrp` 的 `AttachmentFile` 并关联记录
- [x] 3.4 检查 `AttachmentService` / `OssUploadService` 的 bizType 映射是否需补充 `UrbanPhoto`

## 4. Urban UI（MaterialClient.Urban）

- [x] 4.1 `UrbanAttendedWeighingViewModel.UpdatePhotoPathsAsync`：相机照片改为匹配 `AttachType.UrbanPhoto`

## 5. 验证

- [x] 5.1 UrbanMode 下完成一次称重：库中抓拍为 `UrbanPhoto`，LRP 为 `Lrp`，UI 两侧照片正常显示
- [x] 5.2 非 UrbanMode 称重：仍为 `UnmatchedEntryPhoto`，无 `UrbanPhoto` / 称重记录级 `Lrp` 关联
