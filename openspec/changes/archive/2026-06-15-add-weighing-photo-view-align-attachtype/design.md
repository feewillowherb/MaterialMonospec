## Context

UrbanManagement Blazor 应用当前状态：

- `WeighingApproval.razor` 在**审批弹层**内通过 `GetApprovalAttachmentsAsync` 加载 LRP / 现场图 Base64 预览，但列表行无独立「查看照片」入口；非审批场景（或仅浏览）无法看图。
- `WeighingRecord.razor` 无任何照片查看能力。
- 服务端 `AttachmentFile.AttachType` 为 `string`，`FileService` / `UrbanAttachmentAppService` 以 `"Lrp"` / `"UrbanPhoto"` 字符串校验与比较。
- MaterialClient 使用 `MaterialClient.Common.Entities.Enums.AttachType`（`short`：`Lrp = 5`、`UrbanPhoto = 6`），上传时经 `ToServerAttachTypeName` 转为字符串。

已有 `GetApprovalAttachmentsAsync` → `FileService.GetApprovalAttachmentImagesAsync` 按字符串分类各取首张 Lrp / UrbanPhoto，可作为统一读图逻辑的基础。

## Goals / Non-Goals

**Goals:**

- 两页列表均提供「查看照片」只读弹层，固定展示 **Lrp** 与 **UrbanPhoto** 两个槽位。
- 服务端 `AttachType` 枚举定义与 `MaterialClient.Common.Entities.Enums.AttachType` **完全一致**（含 `UnmatchedEntryPhoto`、`EntryPhoto`、`ExitPhoto`、`TicketPhoto`、`Lrp`、`UrbanPhoto` 全部成员及数值）。
- UrbanManagement **业务仅使用** `Lrp` 与 `UrbanPhoto`；上传校验、落库、Web 读图与展示仅处理此二值；返回 DTO 按两槽位组织，供审批弹层与查看照片弹层复用。
- MaterialClient.Urban 上传 API 请求体 `attachType` 改为枚举整型，消除字符串映射。

**Non-Goals:**

- 不在 Web 端编辑、上传或删除附件。
- 不展示 `EntryPhoto`、`UnmatchedEntryPhoto` 等其他客户端附件类型。
- 不改造政府同步 `ReadAttachmentFilesAsync` 的批量 Base64 列表语义（仍可返回全部关联附件；若需按类型过滤可后续迭代）。
- 不实现全屏/lightbox 级图片查看器（本期弹层内 `<img>` 展示即可）。

## Decisions

### 1. 统一附件读 API，重命名 DTO 为通用语义

**选择**：保留 `IUrbanWeighingRecordAppService.GetApprovalAttachmentsAsync(Guid id)` 方法名（避免破坏性路由变更），将返回 DTO 重命名为 `UrbanWeighingRecordAttachmentsDto`（或保留原名但文档标明通用），字段保持 `LrpImageBase64` / `UrbanPhotoImageBase64`，内部按 `AttachType.Lrp` / `AttachType.UrbanPhoto` 枚举比较。

**备选**：新增 `GetAttachmentsAsync` 并让审批/查看共用 — 路由增多，收益有限。

### 2. AttachType 保留完整枚举定义，业务仅使用 Lrp / UrbanPhoto

**选择**：`UrbanManagement.Core.Entities.Enums.AttachType` 与 MaterialClient 定义**完全一致**（全部成员及数值），`AttachmentFile.AttachType` 存为 `AttachType` 枚举（底层 `smallint`）：

```csharp
public enum AttachType : short
{
    UnmatchedEntryPhoto = 0,
    EntryPhoto = 1,
    ExitPhoto = 2,
    TicketPhoto = 3,
    Lrp = 5,
    UrbanPhoto = 6
}
```

UrbanManagement 本期**仅允许**通过上传 API / `FileService` 创建 `Lrp`、`UrbanPhoto` 附件；Web 读图与展示仅分类此二值。其他枚举成员保留用于跨端类型码对齐，不在 Urban 城管流程中使用。

**备选**：仅定义 Lrp/UrbanPhoto 两个成员 — 与客户端枚举不一致，拒绝。

### 3. 上传 API `attachType` 使用整型枚举

**选择**：`UrbanAttachmentUploadInputDto.AttachType` 改为 `AttachType` 枚举；JSON 序列化为数字 `5` / `6`。MaterialClient `UrbanAttachmentUploadRequestDto` 同步改为 `short` 或 `AttachType`，移除 `ToServerAttachTypeName` 字符串转换。

**备选**：同时接受 string 与 int — 增加兼容层复杂度，本期不做。

### 4. Web UI：共享照片弹层组件

**选择**：抽取 Blazor 片段或小型组件（如 `WeighingPhotoDialog.razor`），props：`RecordId`、`PlateNumber`（标题用）、`OnClose`。打开时调用 `GetApprovalAttachmentsAsync`，展示双图布局（与审批弹层 `.approval-images` 样式复用）。

`WeighingRecord.razor`：操作列增加「查看照片」。
`WeighingApproval.razor`：操作列增加「查看照片」（与「审批」「修改历史」并列）；审批弹层继续内嵌图片预览，逻辑可调用同一加载方法。

### 5. FileService 分类逻辑

**选择**：`GetApprovalAttachmentImagesAsync` 遍历关联附件时：

```csharp
if (attachment.AttachType == AttachType.Lrp && lrpBase64 == null) ...
else if (attachment.AttachType == AttachType.UrbanPhoto && urbanPhotoBase64 == null) ...
```

忽略非 Lrp/UrbanPhoto 枚举值（防御性；正常数据不应存在）。

`SaveAndCompressImagesAsync` 签名改为 `AttachType attachType` 参数，校验仅为 `Lrp` / `UrbanPhoto`。

### 6. 数据库迁移

**选择**：新增 EF 迁移，将 `AttachmentFile.AttachType` 列从 `nvarchar` 转为 `smallint`：

| 旧值 (string) | 新值 (short) |
|---------------|--------------|
| `Lrp`         | `5`          |
| `UrbanPhoto`  | `6`          |

空值或未知字符串 → 迁移脚本删除或设为默认值并记录日志（若存在）。

项目处于 squash 后早期阶段，可接受一次性数据迁移。

## Risks / Trade-offs

- **[Risk] BREAKING API**：客户端仍发 `"Lrp"` 字符串 → 部署须 UrbanManagement 与 MaterialClient 同步升级。**Mitigation**：联调前更新 Refit DTO；无生产混合版本需求时一次性发布。
- **[Risk] 历史 DB 含非法 AttachType 字符串** → 迁移 SQL 映射失败。**Mitigation**：迁移前查询 distinct 值；仅 `Lrp`/`UrbanPhoto` 映射，其余行跳过或人工处理。
- **[Risk] 审批弹层与查看照片重复加载逻辑** → 代码重复。**Mitigation**：抽取 `LoadAttachmentsAsync(Guid id)` 私有方法或共享组件。
- **[Trade-off]** 每类型仅展示首张图 — 与现 `GetApprovalAttachmentImagesAsync` 行为一致；多图场景本期不扩展。

## Migration Plan

1. 合并 UrbanManagement：枚举实体 + EF 迁移 + FileService/AppService 改造。
2. 部署 UrbanManagement，执行迁移。
3. 合并并部署 MaterialClient.Urban 上传 DTO 变更。
4. 验证：客户端上云 → 服务端 DB `AttachType = 5/6` → Web 两页「查看照片」正常显示。

**Rollback**：回滚应用版本；若迁移已执行，需反向迁移脚本将 `smallint` 转回 string（仅紧急场景）。

## Open Questions

- 无。枚举数值、双槽位展示、两页入口范围已在需求中明确。
