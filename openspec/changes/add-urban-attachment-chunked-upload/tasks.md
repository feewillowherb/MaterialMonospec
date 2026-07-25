## 1. UrbanManagement — tusdotnet 端点与落盘

- [ ] 1.1 添加 `tusdotnet` 包依赖，配置 `MapTus`（建议 `/api/urban-attachment/tus`）+ `TusDiskStore`、最大约 16MB、过期默认 60 分钟
- [ ] 1.2 `OnBeforeCreateAsync` 校验 `buildlicenseno` / `attachtype`（仅 5/6）；`OnFileCompleteAsync` 调用 `SaveAndCompressImageBytesAsync` 并记录 `tusFileId → attachmentId`
- [ ] 1.3 新增薄 API：按 fileId 查询或批量 commit 返回 `attachmentIds`；成功后清理 tus 临时文件
- [ ] 1.4 鉴权与现附件上传对齐；确认 multipart/Base64 未改动；文档注明 IIS/反代需支持 PATCH 与 tus 头
- [ ] 1.5 测试：非法 metadata 拒绝、分片完成后 Guid 可查、终止不落盘、multipart/Base64 回归

## 2. MaterialClient — 设置开关与 UI

- [ ] 2.1 在 `SystemSettings` 增加 `EnableChunkedAttachmentUpload`（默认 `false`）
- [ ] 2.2 `SettingsWindow` 系统分区增加「启用附件分片上传」Toggle，绑定并经 `ISettingsService` 保存
- [ ] 2.3 确认旧设置 JSON 缺字段时反序列化为 `false`，行为仍为 multipart

## 3. MaterialClient.Urban — tus 客户端

- [ ] 3.1 引入或实现 .NET tus 客户端适配器（create/PATCH/terminate；chunkSize 默认 256KB；metadata 含 buildlicenseno/attachtype）
- [ ] 3.2 （可选 Refit）调用薄 commit/attachment-id API；保留 multipart 与 Base64 Refit 方法
- [ ] 3.3 `UrbanAttachmentSyncService`：读开关；关→multipart；开→按文件 tus 上传并收集 Guid；失败保持 Pending
- [ ] 3.4 日志区分 multipart vs tus；服务端未部署时失败可轮询重试

## 4. 验证与规范

- [ ] 4.1 端到端：开关开启 → Lrp/UrbanPhoto tus 上传 → 盘上有文件 → Receive 关联正确
- [ ] 4.2 回归：开关关闭时 multipart 与 legacy Base64 仍可用
- [ ] 4.3 `openspec validate add-urban-attachment-chunked-upload --strict`
