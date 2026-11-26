# 移除客户端 OSS 直传并改为经 FdSoft.Material.PublicApi 低峰上传

## Why

当前 `MaterialClient` 桌面端直接集成 `Aliyun.OSS.SDK.NetCore` 并在本地 `appsettings.secret.json` 中持有阿里云 OSS 静态密钥（`Key`、`Secret`、`BucketName`），存在以下问题：

1. **安全与运维风险**：静态 OSS 凭据随工地客户端分发，难以轮换且存在泄露面。
2. **两步上传不一致**：客户端先直传 OSS，再调用 `FdSoft.Material.PublicApi` 的 `POST /api/File/UpdateAttaches` 写 `MaterialAttaches` 元数据表，可能出现文件已传 OSS 但元数据落库失败的半成功状态。
3. **白天业务阻塞隐患**：当前附件上传串行挂在 `PollingBackgroundService` 中且整批包裹在单个 `[UnitOfWork]` 事务内，网络波动或图片积压时会拖慢物料/供应商/运单同步并长时间占用 SQLite 写锁。
4. **未压缩原图占用带宽**：现场抓拍图直接上传，单张体积较大；工地电脑 24 小时常开且图片允许延迟约 10 小时，完全可以将上传错峰至夜间低峰并压缩至约 200KB，避免白天占用带宽与服务器资源。

## What Changes

### 1. `repos/FdSoft.Material`（`FdSoft.Material.PublicApi` + `FdSoft.Service` + `FdSoft.Model`）

- 在 `FdSoft.Material.PublicApi` 新增受 JWT `[Authorize]` 保护的附件流式上传接口 `POST /api/File/UploadAttachment`（`multipart/form-data`）：
  - 将 `FileController` 类级别的 `[AllowAnonymous]` 下沉至历史兼容 Action（`UpLoadFile`、`AddAttaches`、`UpdateAttaches`），或使用继承 `BaseController` 的独立受保护 Action，确保新接口严格校验 JWT Bearer Token，无需新增额外授权密钥。
  - 客户端仅传 `File`、`BizId`、`BizType`、`FileName`（及可选审计时间），不再传 `Bucket` 与 `BucketKey`；服务端读取自身 `ALIYUN_OSS` 配置并按 `BizType` + 日期生成 `BucketKey`。
  - 对上传路由跳过全局 `context.Request.EnableBuffering()`，纯内存/流式直接转发至阿里云内网 OSS，**服务器本地不保存任何图片文件**。
  - 重复上传同一 `(BizId, BizType, FileName)` 时覆盖 OSS 对象并更新 `MaterialAttaches` 记录；响应 `data` 返回 `FileId`、`Bucket`、`BucketKey` 与访问路径信息。
  - 增加接口级并发限流（`SemaphoreSlim`），超限时直接返回 HTTP `429 Too Many Requests`，保障核心业务接口不受上传流量冲击；限制单文件大小上限（默认 5MB）。
- **向后兼容**：保留既有 `POST /api/File/UpdateAttaches`、`AddAttaches` 供老版本客户端平滑过渡。

### 2. `repos/MaterialClient`（`MaterialClient.Common` + `MaterialClient.Desktop.Hosting` + 宿主配置）

- **彻底移除客户端 OSS 依赖与凭据**：
  - 移除 `IOssUploadService`、`OssUploadService`、`AliyunOssConfig` 及 `MaterialClientCommonModule` 中的 `AliyunOss` 选项注册。
  - 从 `MaterialClient.Common.csproj` 移除 `Aliyun.OSS.SDK.NetCore` 包引用。
  - 清理宿主 `appsettings.secret.json` 中的 `AliyunOss` 配置节。
- **客户端上传前内存压缩至约 200KB**：
  - 在 `JpegCompressionUtil` 中新增纯内存按目标体积自适应压缩方法（目标约 200KB），不修改客户端本地留存的原图；压缩失败时 fail-safe 回退为原字节流。
- **改由 `IMaterialPlatformApi` 上传并拆分为独立低峰后台 Worker**：
  - 在 `IMaterialPlatformApi` 新增 `[Multipart]` 的 `UploadAttachmentAsync` 方法，自动复用 `MaterialPlatformBearerTokenHandler` 携带的 JWT Bearer Token。
  - 将附件上传从 `PollingBackgroundService` 中拆出，新增独立的 `AttachmentUploadBackgroundService`：
    - 默认仅在夜间低峰窗口（如 `20:00`–`07:00`，可配置）自动运行，并在窗口起始处叠加随机抖动（Jitter，默认 0–30 分钟）防止多工地整点齐射。
    - 白天自动上传完全静默（0 流量、0 锁库）；保留界面“数据同步”手动触发入口以便运维按需即时补传。
    - 拆掉长事务：只读查询待上传批次 → 事务外逐张压缩并调用 `PublicApi` → 单张成功后再开短事务更新 `AttachmentFile.OssFullPath` 与 `LastSyncTime`。
    - 遇到 HTTP `429`、`401` 或网络异常时静默中止本轮并留待下一轮重试。

## Capabilities

### New Capabilities

- `publicapi-attachment-upload`: `FdSoft.Material.PublicApi` 提供受 JWT 保护的流式附件上传接口，内存直转内网 OSS（服务器本地不存图）、同键覆盖更新 `MaterialAttaches` 并提供并发限流保护。
- `client-publicapi-attachment-sync`: `MaterialClient` 移除本地 OSS SDK 与密钥，改为通过 `FdSoft.Material.PublicApi` 上传并在独立夜间低峰后台任务中按短事务 + 随机抖动执行，确保白天零阻塞。

### Modified Capabilities

- `manual-data-sync-trigger`: 手动“数据同步”流程的第 5 步由直传 OSS（`SyncPendingAttachmentsToOssAsync`）更新为经 `FdSoft.Material.PublicApi` 上传待同步附件（`SyncPendingAttachmentsAsync`）。
- `jpeg-capture-compression`: 在 `JpegCompressionUtil` 扩展面向目标体积（约 200KB）的纯内存自适应 JPEG 压缩能力，供客户端上传前使用且不覆盖本地原图。

## Impact

- **跨仓库影响（Mode A — Trunk-direct）**：
  - `repos/FdSoft.Material`：`FdSoft.Material.PublicApi`、`FdSoft.Service`、`FdSoft.Model`
  - `repos/MaterialClient`：`MaterialClient.Common`、`MaterialClient.Desktop.Hosting`、`MaterialClient.AttendedWeighing`、各桌面宿主配置文件及测试项目
- **安全与部署**：
  - 客户端不再保存任何 OSS 密钥，减少凭据泄露面。
  - 需确认 `FdSoft.Material.PublicApi` 生产环境 `ALIYUN_OSS:bucketName` 等配置已填写实际值（而非仓库模板中的占位符）。
- **兼容性**：
  - 保留 `PublicApi` 的 `POST /api/File/UpdateAttaches`，老版本客户端不受影响。
  - 客户端 SQLite `AttachmentFile` 表结构保持兼容（继续复用 `OssFullPath` 与 `LastSyncTime` 字段判定同步状态），无需数据库结构迁移。
  - `MaterialClient.Urban` 与 `MaterialClient.Recycle` 走独立上传通道，不受本次变更影响。
