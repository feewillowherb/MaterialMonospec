## 1. UrbanManagement — 存储路径与上传 API

- [x] 1.1 确认/调整 `FileService`：将 `StorageOptions.FilesPhysicalPath`（默认 `Uploads/`）与 `IContentRootPath` 组合为绝对根目录；启动时记录解析路径并确保目录可写
- [x] 1.2 新增 `UrbanAttachmentUploadInputDto` / `UrbanAttachmentUploadOutputDto`（`buildLicenseNo`、`attachType`、`images[]` → `attachmentIds[]`）
- [x] 1.3 新增 `IUrbanAttachmentAppService.UploadAsync`，内部调用 `IFileService.SaveAndCompressImagesAsync`；校验 `attachType` 仅为 `Lrp` / `UrbanPhoto`
- [x] 1.4 为上传 API 添加单元/集成测试：文件落盘于 `{ContentRoot}/Uploads/TempUpload/{buildLicenseNo}/` 且 DB 存在 `AttachmentFile` Guid

## 2. MaterialClient.Urban — Refit 与上传辅助

- [x] 2.1 扩展 `IUrbanManagementApi`（或独立 Refit 接口）及 DTO，对接 `POST /api/app/urban-attachment/upload`（以 ABP 实际路由为准）
- [x] 2.2 实现附件读取辅助：按 `weighingRecordId` 取 `Lrp`/`UrbanPhoto`，`LocalPath` 归一化后读字节转 Base64
- [x] 2.3 按 `AttachType` 分组调用上传 API，合并返回的 `Guid` 列表

## 3. MaterialClient.Urban — 上云管线集成

- [x] 3.1 修改 `UrbanServerUploadService.SubmitRecordAsync`：先上传附件，再 `ReceiveWeighingRecordAsync`，设置 `AttachmentIds`（移除硬编码 `null`）
- [x] 3.2 失败语义：上传/Receive 失败时不更新 `SyncStatus` 为 Synced；记录日志供轮询重试
- [x] 3.3 从 `LicenseInfo` 填充 `buildLicenseNo`；缺失时使用约定占位并打 Warning

## 4. 验证与文档

- [ ] 4.1 联调：Urban 产生称重 + 本地附件 → 等待轮询 → 服务端存在 `UrbanWeighingRecordAttachment` 与 `Uploads/TempUpload/...` 物理文件
- [ ] 4.2 验证 `GovSyncBackgroundWorker` 对有附件记录能 `ReadAttachmentFilesAsync` 得到 Base64（可选，依赖测试环境）
- [x] 4.3 更新 `repos/MaterialClient` / UrbanManagement README 或 AGENTS：说明 `UrbanManagement:BaseUrl` 与服务端 `Uploads/` 目录部署位置
