# 实施任务清单

> Git 工作流模式：**Mode A — Trunk-direct**。首次改动各涉及子仓代码前，须自各仓 trunk 切出同名分支 `refactor-client-oss-upload-to-publicapi`。

## 1. `repos/FdSoft.Material` — PublicApi 流式上传与限流保护

- [x] 1.1 在 `FdSoft.Model` 新增上传请求表单模型 `UploadAttachmentFormDto` 与命名 `record` 响应模型 `UploadAttachmentResultDto(int FileId, string Bucket, string BucketKey, string? FileUrl)`
- [x] 1.2 在 `FdSoft.Material.PublicApi` 新增并发限流器 `AttachmentUploadConcurrencyLimiter`（基于 `SemaphoreSlim`，支持 `AttachmentUpload:MaxConcurrentUploads` 配置，默认 12）与单文件大小上限配置（`AttachmentUpload:MaxFileSizeBytes`，默认 5MB），并在 `Program.cs` 中对 `/api/File/UploadAttachment` 跳过 `context.Request.EnableBuffering()`
- [x] 1.3 在 `FdSoft.Service`（`IFileService` / `FileService`）实现 `UploadAttachmentAsync`：从服务端 `ALIYUN_OSS:bucketName` 读取 Bucket、复用同 `(BizId, BizType, FileName)` 已有 `BucketKey` 或按 `BizType` + 日期生成 `BucketKey`、纯内存流式上传至阿里云 OSS（服务器本地不落盘）、Upsert `MaterialAttaches` 单份记录（覆盖更新，不写 `Compression_` 副记录）并返回 `UploadAttachmentResultDto`
- [x] 1.4 在 `FdSoft.Material.PublicApi/Controllers/FileController.cs` 将 `[AllowAnonymous]` 从类级下沉到既有历史 Action（`UpLoadFile`、`AddAttaches`、`UpdateAttaches`），新增继承 `BaseController` `[Authorize]` 的 `POST /api/File/UploadAttachment`（并发超限返回 HTTP `429` + `Retry-After`）
- [x] 1.5 编译验证 `FdSoft.Material.PublicApi`（0 Errors；该仓暂无独立单元测试项目，接口行为待 3.2 联调验证）

## 2. `repos/MaterialClient` — 移除客户端 OSS 并实现 ~200KB 压缩与低峰上传

- [x] 2.1 在 `MaterialClient.Common/Utils/JpegCompressionUtil.cs` 修正 `GetJpegCodecInfo()` 为 `ImageCodecInfo.GetImageEncoders()`，并新增纯内存自适应压缩方法 `CompressToTargetSize` 与 `CompressedImagePayload` record（默认目标 200KB，不修改本地原图，异常时 fail-safe 返回原字节）
- [x] 2.2 在 `MaterialClient.Common/Configuration/AttachmentUploadOptions.cs` 新增低峰上传配置项（`Enabled`、`OffPeakWindowOnly`、`WindowStartHour=20`、`WindowEndHour=7`、`MaxJitterMinutes=30`、`PollIntervalMinutes=15`、`BatchSize=20`、`TargetMaxSizeKb=200`、`UploadTimeoutSeconds=60`）并在 `MaterialClientCommonModule` 中绑定配置
- [x] 2.3 在 `MaterialClient.Common/Api/IMaterialPlatformApi.cs` 新增 `[Multipart]` 的 `UploadAttachmentAsync`（使用 `ByteArrayPart`）及 `UploadAttachmentResultDto` record，并在 `RefitClientRegistrationExtensions.cs` 确保上传超时与 `429` 退避行为符合设计
- [x] 2.4 重构 `IAttachmentService` / `AttachmentService`：移除 `IOssUploadService`、`IOptions<AliyunOssConfig>` 与 `UpdateAttachesAsync` 依赖；实现短事务拆分的 `SyncPendingAttachmentsAsync`（只读查批次 → 事务外内存压缩至 ~200KB 并调用 `PublicApi` → 单张成功短事务写回 `OssFullPath` 与 `LastSyncTime`；遇 HTTP `429`/`401` 静默中止本轮）；更新 `AttendedWeighingViewModel` 手动同步入口调用新方法
- [x] 2.5 从 `PollingBackgroundService` 移除附件上传步骤，新增独立的 `AttachmentUploadBackgroundService`（低峰时间窗口判断 + 每窗口随机抖动 Jitter）并在桌面宿主模块中注册
- [x] 2.6 移除客户端 OSS 相关文件与配置：删除 `OssUploadService.cs`、`AliyunOssConfig.cs`、`MaterialClientCommonModule` 中的 `AliyunOss` 注册、`MaterialClient.Common.csproj` 中的 `Aliyun.OSS.SDK.NetCore` 引用，以及各宿主 `appsettings.secret.json` 中的 `AliyunOss` 配置节
- [x] 2.7 补充单元测试（`AttachmentUploadCompressionAndWindowTests`：12/12 通过），并编译验证 `MaterialClient`、`MaterialClient.SolidWaste`、`MaterialClient.Urban` 宿主（0 Errors）

## 3. 联调与部署核对

- [x] 3.1 核对 `FdSoft.Material.PublicApi` 目标部署环境的 `ALIYUN_OSS:bucketName`、`REGIONID`、`KEY`、`SECRET` 为真实可用配置
- [ ] 3.2 端到端验证：客户端上传 >1MB 现场照片 → 客户端压至 ~200KB → `PublicApi` 鉴权通过并内网直传 OSS（服务器本地无残留文件）→ 重复上传覆盖成功 → `MaterialAttaches` 与客户端 `AttachmentFile` 状态一致
