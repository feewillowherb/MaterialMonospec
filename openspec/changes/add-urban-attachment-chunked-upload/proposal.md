## Why

现场部分客户端到 UrbanManagement 的链路在传输较大附件时出现 HTTP 上传卡住、连接被重置或触发 `HttpClient` 240 秒超时，而小请求与 SignalR 心跳仍可能正常。整文件 multipart 一次失败即整单重来，弱网/MTU 不佳场景下 Pending 堆积。需要可选的 **分片/可续传上传** 通道，并由 **系统设置开关** 控制是否启用（默认关闭）。本期采用成熟的 **tus 协议 + tusdotnet**，避免自研会话/拼片存储。

## What Changes

- UrbanManagement 引入 **tusdotnet**，在专用端点（建议 `/api/urban-attachment/tus`）提供 tus 1.0 可续传上传；上传元数据携带 `buildLicenseNo`、`attachType` 等。
- 文件 tus 上传完成后，经现有 `SaveAndCompressImageBytesAsync` 落盘，并向客户端提供获取 `attachmentIds` 的薄查询/提交接口（因 tus 完成响应本身不返回业务 Guid）。
- UrbanManagement **保留**现有 multipart 与 Base64 上传端点；tus 为可选并行通道，非 BREAKING。
- MaterialClient.Urban 在 **系统设置** 中增加「启用附件分片上传」开关（默认关闭）；开启后走 tus 客户端上传，关闭时继续默认 multipart。
- 失败语义与现网一致：不标记 `Synced`，保持 `Pending`，由轮询补传。
- OpenSpec：扩展 `attachment-file-storage`、`urban-client-attachment-sync`、`settings-ui`。

非目标（本期不做）：

- 不宣称用分片根治 MTU/DF（现场仍应修路径 MTU）。
- 不改为 OSS / SignalR 传图。
- 不合并「上传附件 + Receive」为单请求。
- 不删除 multipart 或 Base64 上传实现。
- 不引入 EasyAbp.FileManagement。

## Capabilities

### New Capabilities

- （无）本期扩展既有附件存储与客户端同步能力，不引入独立新 capability 名。

### Modified Capabilities

- `attachment-file-storage`: 新增基于 tusdotnet 的可续传上传端点；完成后复用字节落盘并暴露 `attachmentIds` 获取方式；multipart/Base64 保留。
- `urban-client-attachment-sync`: 系统设置开关控制 multipart vs tus；开启时用 tus 协议分片上传并收集 Guid；失败/Pending 语义不变。
- `settings-ui`: 系统设置界面增加「启用附件分片上传」开关，持久化到 `SystemSettings`，默认关闭。

## Impact

| 仓库 | 影响 |
|------|------|
| **UrbanManagement** | NuGet `tusdotnet`；`MapTus` 端点 + `TusDiskStore`；`OnFileComplete` → `IFileService`；薄接口返回 Guid；multipart/Base64 不变 |
| **MaterialClient** | `SystemSettings` + 设置 UI 开关；tus 协议客户端（非 Refit 主路径）；`UrbanAttachmentSyncService` 按开关分支 |
| **API** | tus 端点建议 `/api/urban-attachment/tus`；另需 Guid 查询/提交路由；旧路由不变（非 BREAKING） |
| **部署** | IIS/反向代理需允许 PATCH 及 `Tus-*` / `Upload-Offset` 等头；单文件上限对齐约 16MB |
| **规范** | 更新上述 specs |
| **依赖** | 新增 tusdotnet；客户端可选社区 tus 库或自研薄 HttpClient tus 适配 |
