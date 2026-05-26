## 1. ViewModel — 附件加载与查看命令

- [x] 1.1 为 `WeighingRecordEditDialogViewModel` 注入 `IAttachmentService`、`IServiceProvider`、`ILogger`；新增 `LprPhotoPath`、`CameraPhotoPath`、可选 `LprPhotoTime` / `CameraPhotoTime` 响应式属性
- [x] 1.2 实现 `LoadPhotosAsync(long weighingRecordId)`：调用 `GetAttachmentsByWeighingRecordIdsAsync`，按 `AttachType.Lrp` / `AttachType.UrbanPhoto` 填充路径（逻辑对齐 `UrbanAttendedWeighingViewModel.UpdatePhotoPathsAsync`）
- [x] 1.3 添加 `OpenLprImageViewerCommand` / `OpenCameraImageViewerCommand`，复用 `ImageViewerWindow` + `ImageViewerViewModel.SetImage` 模式；空路径不打开；异常记日志

## 2. 对话框 UI

- [x] 2.1 更新 `WeighingRecordEditDialog.axaml`：加宽布局，双列 LRP / UrbanPhoto 缩略图（标题、时间、可点击 `Image` + `CarNullOrEmptyImageConverter`）
- [x] 2.2 绑定查看命令与路径属性；保留车牌号、重量、取消/确定按钮

## 3. 审批入口集成

- [x] 3.1 更新 `UrbanAttendedWeighingViewModel.ApproveRecordAsync`：创建对话框 ViewModel 时传入 `item.WeighingRecordId` 并 `await LoadPhotosAsync` 后再 `ShowDialog`
- [x] 3.2 若 ViewModel 改为 DI 创建，在 Urban 模块注册 `WeighingRecordEditDialogViewModel` 为 transient（仅当采用 DI 时）— **跳过**：仍用 `new` + `GetRequiredService` 注入依赖

## 4. 验证

- [ ] 4.1 手动验证：仅有 LRP、仅有 UrbanPhoto、两者皆有、皆无；点击缩略图全屏查看；确定后仍正常 `UpdateWeighingRecordAsync`
- [x] 4.2 `dotnet build` MaterialClient.Urban 通过
