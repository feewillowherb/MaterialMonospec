## Context

- **现状**：`UrbanServerUploadService` 查询本地 `WeighingRecordAttachment` 后仍将 `AttachmentIds = null` 提交；`IUrbanManagementApi` 仅有 `POST /api/app/urban-weighing-record/receive`。本地 `AttachmentFile` 主键为 `int`，服务端为 `Guid`。
- **服务端已有能力**（迁移 change 已实现）：`IFileService.SaveAndCompressImagesAsync(base64[], buildLicenseNo, attachType) → List<Guid>`，落盘路径 `{FilesPhysicalPath}/TempUpload/{buildLicenseNo}/{ticks}_{i}.jpg`；`ReceiveAsync` 支持 `AttachmentIds` 建 `UrbanWeighingRecordAttachment`。
- **配置**：`appsettings.json` 中 `StorageOptions.FilesPhysicalPath` 默认为 `"Uploads/"`，用户要求该目录位于 **UrbanManagement 服务运行目录** 下（即相对 `IContentRootPath` / `AppContext.BaseDirectory` 解析，而非客户端目录）。
- **触发**：`PollingBackgroundService` → `SubmitRecordAsync`（与称重元数据同批、同 UOW 外 HTTP 调用）。

## Goals / Non-Goals

**Goals:**

- 每条 Pending 称重记录上云时，将关联的 `Lrp` / `UrbanPhoto` 上传至 UrbanManagement，文件写入 `Uploads/`（经 `FilesPhysicalPath` 配置）下约定子目录，并在 `Receive` 时携带服务端 `Guid` 列表。
- 复用服务端 `IFileService` 压缩与 `AttachmentFile` 建表逻辑，避免重复实现存储。
- 上传失败时记录保持 Pending，可轮询重试；幂等 `ClientRecordId` 行为不变。

**Non-Goals:**

- 不改造主程序 MaterialClient 的 OSS 附件同步。
- 不在本 change 实现 Web 审批弹层图片展示/编辑。
- 不将客户端本地 `int` 附件 ID 直接当作服务端 ID 使用。
- 不改变 `GovSyncHttpClient` 政府 API 载荷结构（仅确保服务端有关联附件可供 `ReadAttachmentFilesAsync` 读盘）。

## Decisions

### D1: 两阶段 HTTP — 先上传图片，再 Receive 称重记录

**选择**：`SubmitRecordAsync` 内顺序为：(1) 按附件类型批量调用上传 API；(2) 收集返回的 `List<Guid>`；(3) `ReceiveWeighingRecordAsync` 带 `attachmentIds`。

**理由**：与 legacy `LegacyApiController` → `FileService` → `ReceiveAsync` 序列一致；服务端 `AttachmentIds` 必须引用已存在的 `AttachmentFile` Guid。

**备选**：单请求 multipart 同时传 JSON + 文件 — 需新契约，与 ABP 现有 Base64 `IFileService` 不一致。

### D2: 服务端暴露 `IUrbanAttachmentAppService`（ABP 约定路由）

**选择**：在 UrbanManagement.Core 新增应用服务，例如：

- `POST /api/app/urban-attachment/upload`  
- Body：`buildLicenseNo`、`attachType`（`Lrp` | `UrbanPhoto`）、`images`（Base64 字符串数组）  
- Response：`{ attachmentIds: Guid[] }`  

内部委托 `IFileService.SaveAndCompressImagesAsync`。

**理由**：MaterialClient 已用 Refit + ABP 路由；无需新建 Controller 层。

### D3: `FilesPhysicalPath` 解析规则

**选择**：`FileService` 将配置的 `FilesPhysicalPath`（默认 `Uploads/`）与 `IWebHostEnvironment.ContentRootPath`（或等效 `AppContext.BaseDirectory`）组合为绝对根目录；相对路径写入 `AttachmentFile.LocalPath` 时仍存相对于该根目录的路径（与现网政府同步读盘一致）。

**示例**：ContentRoot = `D:\app\UrbanManagement.App\`，配置 `Uploads/` → 根目录 `D:\app\UrbanManagement.App\Uploads\`，文件 `TempUpload\BL001\638123_0.jpg`。

**理由**：满足「Uploads 在服务运行目录下」；保留 `TempUpload/{buildLicenseNo}/` 子结构，避免与既有数据/规范冲突。

### D4: 客户端 Refit — `IUrbanManagementApi.UploadAttachmentsAsync`

**选择**：在 `MaterialClient.Urban` 扩展 `IUrbanManagementApi`，DTO 与 D2 对齐；新建 `IUrbanAttachmentUploadHelper`（或内联于 `UrbanServerUploadService`）负责：

1. `IAttachmentService.GetAttachmentsByWeighingRecordIdsAsync` 取附件元数据  
2. `AttachmentPathUtils`（或现有路径工具）归一化 `LocalPath`  
3. `File.ReadAllBytes` → Base64  
4. 按 `AttachType` 分组调用上传 API（Lrp 一批、UrbanPhoto 一批，或每张单独调用 — 以实现简单为准，推荐按类型各一次 `SaveAndCompressImagesAsync` 调用）

**理由**：与 `file-api-relative-path-normalization` 一致；分组减少 HTTP 往返。

### D5: 失败语义

**选择**：

- 某张本地文件不存在：打 Warning，跳过该张，继续其余附件；若最终 `attachmentIds` 为空仍可提交称重（与「无附件」场景一致），或若业务要求「有本地附件则必须全部成功」则在 design 实现时二选一 — **默认：有附件记录但全部读盘失败则整单不上传并保留 Pending**。
- HTTP 上传或 Receive 抛错：不更新 `SyncStatus` 为 Synced（与现 `UrbanServerUploadService` catch 行为一致）。

### D6: 幂等与重复上传

**选择**：`Receive` 仍按 `ClientRecordId` 幂等；重复轮询时若记录已 Synced，Worker 不再处理。若 Pending 重试导致重复上传图片，服务端可能产生多余 `AttachmentFile` 行 — **首期接受**；follow-up 可加客户端标记「附件已上传」或 Receive 幂等时仅关联新 Guid。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 大图片 Base64 导致请求体过大 | 复用服务端压缩；客户端可限制单张大小或分张上传 |
| 重复轮询产生孤儿 AttachmentFile | 日志监控；后续扩展附件同步状态列 |
| ContentRoot 与部署目录不一致 | 启动时记录解析后的绝对 `Uploads` 路径；文档说明 IIS/Kestrel 工作目录 |
| buildLicenseNo 为空 | 使用 `LicenseInfo.BuildLicenseNo`，为空时用占位符 `unknown` 并打 Warning |

## Migration Plan

1. 部署 UrbanManagement（新 API + 确认 `Uploads/` 目录可写）。
2. 部署 MaterialClient.Urban（Refit + `SubmitRecordAsync` 变更）。
3. 验证：新称重 → Pending → 轮询后服务端 DB 有 `UrbanWeighingRecordAttachment` 且 `Uploads/TempUpload/...` 存在文件。
4. 回滚：旧客户端仅元数据上云仍可工作；新客户端回滚后恢复无图状态。

## Open Questions

- 是否要求「至少一张 UrbanPhoto 成功才提交记录」— 默认否，与当前「可无 LRP」一致。
- 单条记录附件很多时是否合并为一次 API — 实现阶段按 `SaveAndCompressImagesAsync` 批量上限（如每请求 ≤10 张）拆分。
