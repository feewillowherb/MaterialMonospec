## 1. UrbanManagement — FileService 共享字节入口

- [x] 1.1 在 `IFileService` / `FileService` 新增 `SaveAndCompressImageBytesAsync(IReadOnlyList<byte[]>, buildLicenseNo, attachType)`，复用现有目录、压缩阈值与 `AttachmentFile` 创建逻辑
- [x] 1.2 将现有 `SaveAndCompressImagesAsync(string[] base64, …)` 改为 Base64 解码后委托字节入口，保证 legacy 行为不变
- [x] 1.3 为字节入口补充/更新单元测试（合法 attachType、非法 attachType、空数组）

## 2. UrbanManagement — multipart 端点（保留 Base64）

- [x] 2.1 新增 MVC Controller（如 `UrbanAttachmentController`）实现 `POST /api/urban-attachment/upload-multipart`：`[FromForm] buildLicenseNo`、`attachType`、`IFormFile` 集合
- [x] 2.2 Controller 校验 `BuildLicenseNo` 与 `AttachType.IsUrbanWeighingAttachment()`，读文件字节后调用 `SaveAndCompressImageBytesAsync`，返回与 legacy 相同的 `attachmentIds` DTO
- [x] 2.3 确认 `UrbanAttachmentAppService.UploadAsync`（Base64 JSON）保持可用；加 legacy/deprecated 注释，**不删除**
- [x] 2.4 核对 `FormOptions.MultipartBodyLengthLimit` / Kestrel / IIS 文档或 `web.config` 与 `SignalR.MessageSizeLimit`（默认 16MB）一致
- [x] 2.5 可选：legacy Base64 调用打结构化日志（便于未来退役统计）

## 3. MaterialClient.Urban — Refit 与同步切换

- [x] 3.1 调整 `IUrbanManagementApi`：去掉或拆分接口级 `Content-Type: application/json`，保证 JSON 方法仍设正确 Header
- [x] 3.2 新增 multipart Refit 方法（`StreamPart`/`ByteArrayPart` + form 字段），**保留**现有 Base64 `UploadAttachmentsAsync` 方法定义不删除
- [x] 3.3 更新 `UrbanAttachmentSyncService`：默认按 attachType 分组用 multipart 上传；将旧 Base64 调用抽成保留方法（如 `UploadAttachmentsBase64Async`）供回退，默认路径不调用
- [x] 3.4 更新/新增序列化或集成测试：multipart 请求不含全局 JSON Content-Type；Base64 DTO/方法仍可编译

## 4. 验证

- [x] 4.1 端到端：本地有 Lrp + UrbanPhoto → multipart 上传 → Receive 带 Guid → 服务端盘上有文件且关联正确
- [x] 4.2 回归：直接调用 legacy Base64 `upload` 仍成功返回 `attachmentIds`
- [x] 4.3 `openspec validate add-urban-attachment-multipart-upload --strict`
