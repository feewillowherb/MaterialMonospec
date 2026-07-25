## Context

- **现状**：MaterialClient.Urban 默认经 Refit `[Multipart]` 调用 `POST /api/urban-attachment/upload-multipart`；失败保持 `Pending`，轮询补传。Base64 JSON 路径仍保留。
- **问题**：部分链路大体积整文件上传易卡住/重置/触发 240s 超时；需要可选分片与可续传。
- **约束**：先附件后 Receive；落盘必须复用 `SaveAndCompressImageBytesAsync`；multipart/Base64 不删除；开关默认关；分片不替代修 MTU。
- **选型变更**：相对自研 create/chunk/complete 会话，本期改为 **tus.io + tusdotnet**，复用标准协议与磁盘存储实现。

## Goals / Non-Goals

**Goals:**

- UrbanManagement 用 tusdotnet 暴露 tus 上传端点；完成后写入 `AttachmentFile` 并让客户端拿到 Guid。
- 设置开关：关 = multipart；开 = tus。
- 单片可重试、会话期内可续传；失败不 `Synced`。
- 分片 body 使用明确长度（tus PATCH + `Content-Length` / `Upload-Offset`）。

**Non-Goals:**

- OSS、SignalR 传图、附件+Receive 合并。
- EasyAbp.FileManagement。
- 用 tus 根治 MTU/DF。
- 删除 multipart/Base64。

## Decisions

### D1: 服务端采用 tusdotnet（否决自研会话与 EasyAbp）

**选择**：`tusdotnet` + `TusDiskStore`，端点建议 `MapTus("/api/urban-attachment/tus", ...)`。

**理由**：标准可续传协议；服务端少写拼片/offset 逻辑；生态成熟。

**备选否决**：自研 `/upload-sessions`（重复造协议）；EasyAbp.FileManagement（无分片、引入重）。

### D2: 业务元数据走 tus Upload-Metadata

创建上传时元数据（tus 惯例小写键）至少包含：

| 键 | 含义 |
|----|------|
| `filename` | 原始文件名 |
| `filetype` | 如 `image/jpeg` |
| `buildlicenseno` | 施工许可证/AccessCode |
| `attachtype` | `5` 或 `6` |

非法 `attachtype` 或缺 `buildlicenseno`：在 create 校验（`OnBeforeCreateAsync`）拒绝。

单文件上限对齐现网约 **16MB**；过期默认 **60 分钟**（tus expiration 扩展）。

### D3: 完成后落盘 + 薄接口返回 attachmentId

tus 协议完成响应**不携带**业务 `attachmentIds`。因此：

1. `OnFileCompleteAsync`：读完成文件字节 → `SaveAndCompressImageBytesAsync`（单图列表）→ 将 `tusFileId → AttachmentFile.Id` 写入短时结果缓存/旁路表/ sidecar。
2. 客户端在该文件 tus 上传成功后调用薄 API，例如：  
   `GET /api/urban-attachment/tus/{fileId}/attachment-id`  
   或批量：`POST /api/urban-attachment/tus/commit` + `{ fileIds: [...] }` → `{ attachmentIds: [...] }`。

**推荐**：单文件 GET 简单；同 `AttachType` 多图时循环 tus 再收集 Guid（与今日按类型分组一致）。

临时 tus 文件在成功落盘并记录 Guid 后删除（或交由 store 过期清理）。

### D4: 鉴权与 ABP 宿主

- `MapTus` 挂在 UrbanManagement HTTP 管道，与现有 `UrbanManagement:BaseUrl` 同源。
- 鉴权与现 multipart 上传对齐（若 multipart 匿名/机器码策略如何，tus 同等）；在 endpoint 上 `RequireAuthorization` 或等价过滤器，避免未授权写盘。
- IIS/反代：放行 **PATCH**、**DELETE**（termination）、自定义头 `Tus-Resumable`、`Upload-Length`、`Upload-Offset`、`Upload-Metadata`。

### D5: 客户端开关与 tus 客户端（非 Refit 主路径）

```csharp
// SystemSettings
public bool EnableChunkedAttachmentUpload { get; set; } = false;
```

- UI：「启用附件分片上传」，默认关。
- `false` → 现有 `[Multipart]` Refit。
- `true` → **tus 协议客户端**（社区 .NET tus 库或基于 `HttpClient` 的薄适配；**不以 Refit 表达 tus 动词/头**）。
- 默认 `chunkSize`：**256KB**（配置常量即可）。
- 单文件失败：终止该 tus 上传并失败本次 `UploadAttachmentsAsync`，保持 Pending；TTL 内可由协议续传，跨轮询可重建上传。
- 保留 multipart / Base64 Refit 方法不删除。
- Guid 查询可用小 Refit/HttpClient 调 D3 薄 API。

### D6: 与 MTU 的关系

tus 缩短单次 PATCH、支持续传；**不能**替代网关/网卡 MTU 与 ICMP 修复。设置文案与运维说明保留该提示。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| Refit 无法直接描述 tus | 独立 tus 客户端适配器，职责清晰 |
| 完成事件与 Guid 查询竞态 | Complete 后再查；或 commit 接口服务端同步落盘并返回 |
| 代理剥离 PATCH/自定义头 | 部署清单明确；现场验收 |
| 误以为可根治 MTU | 文案说明 |
| 开关开着服务端未部署 tus | 失败 Pending + 日志 |
| 双轨维护 | 共用 `IFileService`；开关默认关 |

## Migration Plan

1. 先部署 UrbanManagement（tusdotnet 端点 + Guid 薄 API + 旧通道）。
2. 再部署 MaterialClient.Urban（开关默认关）。
3. 问题站点打开开关验证 Pending 补传。
4. 回滚：关开关回 multipart。
5. 同步建议排查 MTU。

## Open Questions

- .NET tus 客户端具体 NuGet 选型（社区包 vs 自研薄适配）— 实现时选维护活跃、支持 1.0 creation/PATCH/termination 者。
- Guid 回传用单文件 GET 还是批量 commit — **建议批量 commit** 减少往返，实现可二选一但须在 tasks 定一种。
