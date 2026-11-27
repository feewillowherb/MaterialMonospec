## Context

Stage 1 已建立 `src/UrbanManagement.Admin/client/`（Vue 3 + Element Plus + `OpsDataTable` + `ProjectRemoteSelect`）与 `AdminBffEndpoints`。Stage 2 聚焦 4 个数据核查类页面，核心挑战是既要满足 R1（表格行内直接展示 2 张现场图），又不能让列表接口返回几十 MB 的原图 Base64 或产生每页 20 次 N+1 附件请求。

## Goals / Non-Goals

**Goals:**
- 通过单次批量查询填充 `PreviewPhotos`（最多 2 张 `/api/admin/attachments/{id}`），前端使用 `<el-image lazy>` 懒加载与原生灯箱预览。
- 4 个页面全部接入 `OpsDataTable`（R2）、`ProjectRemoteSelect`（R3）、`InlinePhotoPair`（R1）与 URL Query 筛选同步。
- 审批弹窗保留修正车牌/重量、附件查看与车牌图本地替换上传（原生 FileReader，无需 `file-picker.js`）。

**Non-Goals:**
- 本 Stage 不迁移客户端日志与客户端更新，也不下线 Blazor（在 Stage 3 完成）。
- 保留 `UrbanPassageListItemDto.LargeImageBase64List` 字段兼容既有调用方（不删除旧字段）。

## Decisions

1. **图片 URL 端点安全边界**：`GET /api/admin/attachments/{id:guid}` 挂载在 `AdminBffEndpoints` 的 `.RequireAuthorization()` 组下；读取 `AttachmentFile.LocalPath` 后通过 `IStoragePathResolver` 解析绝对路径并校验路径位于存储根目录内，防止路径穿越；按文件扩展名输出 `image/jpeg` / `image/png` / `image/webp` 并返回 `Cache-Control: private, max-age=3600`。
2. **称重/通行批量图片槽位排序**：称重记录优先取 `AttachType.Lpr` 再取 `AttachType.UrbanPhoto`（最多 2 张）；通行记录按创建时间取前 2 张；全部采用命名 `record` `PreviewPhotoItemDto(Guid AttachmentId, string Label, string Url)`。
3. **卡口与成品共享视图**：抽取 `PassageListView.vue`（通过路由 `props: { source: 'checkpoint' | 'finished' }` 切换接口），消除重复代码。

## Risks / Trade-offs

- **磁盘缺失旧附件**：若数据库有 `AttachmentFile` 记录但物理文件已清理，`GET /api/admin/attachments/{id}` 返回 `404`，`InlinePhotoPair` 的 `#error` 插槽优雅降级为「无图」虚线占位框，不出现裂图。
