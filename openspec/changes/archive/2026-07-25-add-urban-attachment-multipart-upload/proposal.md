## Why

MaterialClient.Urban 当前通过 JSON + Base64 调用 UrbanManagement 附件上传 API。Base64 使请求体约膨胀 33%，且 ASP.NET JSON InputFormatter 必须整包缓冲后再解码，现场大图在 IIS 链路上易出现客户端断连、上传失败并长期停留 Pending。需要在不破坏未升级客户端的前提下，改为二进制 multipart 上传以降低体积与反序列化压力。

## What Changes

- UrbanManagement 新增 **multipart/form-data** 附件上传 HTTP 端点（二进制文件字段 + `buildLicenseNo` / `attachType`），落盘、压缩与返回 `attachmentIds` 语义与现有一致。
- UrbanManagement **保留**现有 Base64 JSON 上传 API（`IUrbanAttachmentAppService.UploadAsync` / `POST .../urban-attachment/upload`），供未升级客户端继续使用；文档/代码标注为 legacy，待全量升级后再开 change 移除。
- `IFileService` 增加接受原始字节（或流）的保存压缩入口，供 multipart 与既有 Base64 路径共用落盘逻辑。
- MaterialClient.Urban 将实际上传调用切换到 multipart 新端点；**不删除**既有 Base64 Refit 方法与 DTO，仅改为走新路径（保留旧代码便于回退与兼容对照）。
- OpenSpec：`attachment-file-storage` 与 `urban-client-attachment-sync` 补充 multipart 需求，并明确 Base64 API 的过渡保留策略。

非目标（本期不做）：

- 不改为 OSS/预签名直传。
- 不合并「上传附件 + Receive」为单请求。
- 不删除服务端或客户端旧 Base64 上传实现。

## Capabilities

### New Capabilities

- （无）本期扩展既有附件存储与客户端同步能力，不引入独立新 capability 名。

### Modified Capabilities

- `attachment-file-storage`: 新增 multipart 上传 API 需求；明确 Base64 上传 API 继续可用直至显式退役 change。
- `urban-client-attachment-sync`: 客户端默认改用 multipart 上传；Base64 Refit 客户端代码保留但不作为默认路径；失败/Pending 语义不变。

## Impact

| 仓库 | 影响 |
|------|------|
| **UrbanManagement** | 新增 multipart Controller（或专用端点）；`IFileService` 字节入口；保留 `UrbanAttachmentAppService`；IIS/`FormOptions`/`MaxRequestBodySize` 与现有 16MB 限额对齐核查 |
| **MaterialClient.Urban** | `UrbanAttachmentSyncService` 改为 multipart；Refit 去掉或拆分全局 `Content-Type: application/json`；保留旧 `UploadAttachmentsAsync` JSON 方法 |
| **API** | 新路由（建议 `POST /api/urban-attachment/upload-multipart`）；旧路由行为不变（非 BREAKING） |
| **部署** | 需确认 IIS `maxAllowedContentLength` ≥ 配置的 multipart 上限 |
| **规范** | 更新上述两个 specs；归档前验证 scripts 可选 |
