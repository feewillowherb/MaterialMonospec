## Context

- **现状**：MaterialClient.Urban `UrbanAttachmentSyncService` 读本地文件 → Base64 → Refit `POST /api/app/urban-attachment/upload`（JSON）→ UrbanManagement `UrbanAttachmentAppService.UploadAsync` → `IFileService.SaveAndCompressImagesAsync(string[] base64, …)` 落盘压缩 → 返回 Guid → `ReceiveWeighingRecordAsync` 带 `attachmentIds`。
- **问题**：Base64 膨胀与 JSON 整包缓冲；现场日志可见 IIS 读 Body / JSON 反序列化过程中 `The client has disconnected`，附件上云失败导致 Pending 堆积。
- **约束**：两阶段「先附件后 Receive」不变；政府同步仍依赖服务端本地盘 `ReadAttachmentFilesAsync`；仅接受 `AttachType.Lpr` / `UrbanPhoto`；**旧 Base64 HTTP API 必须继续可用**；客户端旧上传代码**不删除**，只切换默认调用路径。
- **宿主**：`UrbanManagementAppModule` 已将 `FormOptions.MultipartBodyLengthLimit` 与 Kestrel `MaxRequestBodySize` 绑到 `SignalR.MessageSizeLimit`（默认 16MB）。

## Goals / Non-Goals

**Goals:**

- 新增 multipart 二进制上传端点，语义对齐现有 Base64 API（校验、落盘路径、压缩阈值、返回 `attachmentIds`）。
- 服务端双轨：新 multipart + 旧 Base64 并存。
- 客户端默认改走 multipart；保留 Base64 Refit 方法与 DTO 源码。
- 明确退役策略：未来全量升级后另开 `remove-*` change 删除旧端点与死代码。

**Non-Goals:**

- OSS / 预签名直传、分片续传、合并 Receive。
- 本期删除任一 Base64 上传实现。
- 改造 Web 审批弹层 / SignalR Base64 展示路径（`ReplaceAttachmentAsync` 等可继续用 Base64）。

## Decisions

### D1: 双轨 API — 新 multipart + 保留旧 JSON

**选择**：

| 通道 | 路由（建议） | Content-Type | 状态 |
|------|----------------|--------------|------|
| Legacy | `POST /api/app/urban-attachment/upload` | `application/json`（Base64 `images[]`） | **保留**，行为不变 |
| New | `POST /api/urban-attachment/upload-multipart` | `multipart/form-data` | **新增**，客户端默认 |

Legacy 保留在现有 `IUrbanAttachmentAppService`；新端点用 **专用 MVC Controller**（非 ABP 约定 JSON AppService），避免 `IFormFile` 与约定控制器的绑定问题。

**备选否决**：替换旧端点（破坏未升级客户端）；仅加 AppService 方法指望 ABP 自动绑 multipart（不可靠）。

### D2: multipart 字段契约

**选择**（`multipart/form-data`）：

- `buildLicenseNo`（string，必填）
- `attachType`（short / `AttachType`，仅 5 或 6）
- `files`（一个或多个文件字段，建议同名 `files` 可重复；或 `files[]`）

响应与 legacy 对齐：`{ "attachmentIds": [ Guid, ... ] }`（camelCase）。

校验失败（空许可证号、非法 attachType、无文件）：HTTP 400 / `BusinessException`，不建 `AttachmentFile`。

### D3: `IFileService` 抽取字节入口

**选择**：新增例如：

```csharp
Task<List<Guid>> SaveAndCompressImageBytesAsync(
    IReadOnlyList<byte[]> images,
    string buildLicenseNo,
    AttachType attachType);
```

- `SaveAndCompressImagesAsync(string[] base64, …)` 解码后委托上述方法（legacy 无行为回归）。
- multipart Controller 读 `IFormFile` → `byte[]`（或流式读入内存后压缩；单张通常远小于 16MB）→ 调用字节入口。

不在此 change 引入 `IBlobContainer` / OSS。

### D4: 客户端 Refit 与全局 JSON Header

**选择**：

- 拆分或调整 `IUrbanManagementApi`：去掉接口级 `[Headers("Content-Type: application/json")]`，改为各 JSON 方法自带 Header；multipart 方法不设该 Header。
- 或新增 `IUrbanAttachmentMultipartApi` 专用于 multipart，与现有 JSON 接口并存。
- **保留**现有 `UploadAttachmentsAsync([Body] UrbanAttachmentUploadRequestDto)` 方法定义（不删除）。
- `UrbanAttachmentSyncService.UploadAttachmentsAsync` **默认调用** multipart 方法；可用内部/私有辅助仍保留「读文件 → Base64 → 调旧方法」逻辑路径作为未引用或明确标注 legacy 的代码块（用户要求：不要删除 HTTP 上传旧代码，仅切换）。

推荐实现：保留 `UploadAttachmentsBase64Async`（或同名私有方法）封装旧 Refit 调用；公开流程只调 multipart。

### D5: 批量策略

**选择**：multipart 一次请求可带同 `attachType` 的多文件（对齐今日按类型分组）；失败语义与现有一致（HTTP 失败 → 不 Receive、保持 Pending）。可选后续再拆「单张一请求」——本期不强制。

### D6: 退役策略（文档化，本期不执行）

当监控确认无客户端再调 legacy 路由后，另开 `remove-urban-attachment-base64-upload`：

1. 删除 `UrbanAttachmentAppService.UploadAsync` 与 Base64 DTO 字段用法。
2. 删除客户端 Base64 Refit 方法与死代码。
3. Spec 移除 Base64 上传 requirement。

本期仅在代码注释 / design / proposal 标明「legacy until all clients upgraded」。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| ABP 约定服务绑 multipart 失败 | 使用独立 Controller + `[FromForm]` / `IFormFile` |
| Refit 全局 JSON Content-Type 破坏 multipart | D4 拆 Header 或独立接口 |
| IIS `maxAllowedContentLength` 小于 FormOptions | 部署核对 web.config / IIS 限制 ≥ `MessageSizeLimit` |
| 双轨维护成本 | 共用 `SaveAndCompressImageBytesAsync`；退役 change 已规划 |
| 弱网仍可能中途断连 | 体积已降；失败仍 Pending 重试；不引入分片 |
| 旧客户端与新客户端并存 | 服务端双轨；无 BREAKING |

## Migration Plan

1. 先部署 UrbanManagement（新 multipart + 旧 Base64 均可用）。
2. 再部署 MaterialClient.Urban（默认 multipart）。
3. 验证：新客户端 multipart → 盘上有文件 → Receive 关联 → Gov 可读；旧客户端（或临时切回 Base64 方法）仍可上传。
4. 回滚客户端：改回调用保留的 Base64 Refit 方法即可；服务端无需回滚（双轨）。
5. 未来全量升级后：另开 remove change 删 legacy。

## Open Questions

- multipart 路由最终用 `/api/urban-attachment/upload-multipart` 还是挂在 ABP `api/app/...` 下由手工 Controller 指定 — 实现时以「不与约定 JSON upload 冲突、易被 Refit 调用」为准，推荐前者。
- 是否在响应头或日志对 legacy 调用打 `Deprecated` 指标 — 建议日志 Warning 级别计数，便于退役决策；非阻塞。
