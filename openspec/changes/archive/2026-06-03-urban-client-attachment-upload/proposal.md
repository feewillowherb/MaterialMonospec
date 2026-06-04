## Why

MaterialClient.Urban 在 `PollingBackgroundService` 轮询上云时仅通过 `ReceiveWeighingRecordAsync` 提交称重元数据，并将 `AttachmentIds` 固定为 `null`，导致 LRP / UrbanPhoto 虽在本地落盘，但 UrbanManagement 无法关联图片；政府同步 `GovSyncBackgroundWorker` 从服务端读盘时也无图可传。需在同步管线中补齐「先上传图片、再提交记录并关联附件」的端到端能力。

## What Changes

- **MaterialClient.Urban**：在 `IUrbanServerUploadService.SubmitRecordAsync` 中，对每条待同步称重记录读取本地 `AttachmentFile`（`Lrp`、`UrbanPhoto`），将图片上传至 UrbanManagement，取得服务端 `Guid` 列表后填入 `UrbanWeighingRecordSubmitDto.AttachmentIds`，再调用 `ReceiveWeighingRecordAsync`。
- **UrbanManagement**：对外暴露 ABP 约定 HTTP API（复用 `IFileService`），接收 Base64 图片批次，落盘到 `StorageOptions.FilesPhysicalPath`（默认 `Uploads/`，相对于**服务运行目录 / ContentRoot** 解析），创建服务端 `AttachmentFile` 实体并返回 `Guid` 列表。
- **路径约定**：`FilesPhysicalPath: "Uploads/"` 表示 UrbanManagement 进程工作目录下的 `Uploads` 文件夹（非客户端路径）；文件仍按 `{FilesPhysicalPath}/TempUpload/{buildLicenseNo}/{ticks}_{index}.jpg` 组织，与既有 `attachment-file-storage` 及政府同步读盘逻辑一致。
- **失败与重试**：单张图片上传失败时记录日志；整条记录上传失败时保持 `SyncStatus == Pending`，由轮询重试（与现有称重上云行为一致）。
- **路径归一化**：客户端读取本地 `AttachmentFile.LocalPath` 前 MUST 做相对路径归一化（对齐 `file-api-relative-path-normalization`）。

## Capabilities

### New Capabilities

- `urban-client-attachment-sync`: MaterialClient.Urban 在称重记录上云前/同时上传 LRP 与 UrbanPhoto，并将服务端返回的 `AttachmentFile` Guid 关联到 `Receive` 请求。

### Modified Capabilities

- `attachment-file-storage`: 明确 `FilesPhysicalPath` 相对服务运行目录解析；新增 MaterialClient.Urban 可调用的图片上传 API 需求。
- `urban-weighing-api`: 补充客户端图片上传端点与 `Receive` 时 `attachmentIds` 关联的端到端场景。
- `materialclient-urban-desktop`: 上云管线 MUST 包含附件同步，不得再提交 `attachmentIds: null`。

## Impact

| 范围 | 说明 |
|------|------|
| **MaterialClient.Urban** | `UrbanServerUploadService`、`IUrbanManagementApi`（新增 Refit 上传方法）、可选 `IUrbanAttachmentUploadService` |
| **UrbanManagement** | 新增/暴露 `IFileAppService` 或等价 AppService + DTO；`FileService` 路径解析确保 `Uploads/` 基于 ContentRoot |
| **配置** | 客户端 `UrbanManagement:BaseUrl`；服务端 `StorageOptions.FilesPhysicalPath`（默认 `Uploads/`） |
| **依赖** | 无新外部 NuGet；跨仓库 MaterialClient + UrbanManagement |
| **非目标** | Web 审批弹层图片、客户端 OSS 同步、修改政府 API 载荷格式 |
