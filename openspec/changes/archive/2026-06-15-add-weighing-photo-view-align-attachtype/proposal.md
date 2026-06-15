## Why

UrbanManagement 的称重记录页（`WeighingRecord.razor`）与异常审批页（`WeighingApproval.razor`）缺少独立的「查看照片」能力，管理员无法在列表中直接查看 LRP 与现场抓拍。同时服务端 `AttachmentFile.AttachType` 以字符串 `"Lrp"` / `"UrbanPhoto"` 存储与校验，与 MaterialClient 的 `AttachType` 枚举（`Lrp = 5`、`UrbanPhoto = 6`）不一致，增加跨端映射成本且易出错。

## What Changes

- 在 `WeighingRecord.razor` 与 `WeighingApproval.razor` 表格操作列增加 **「查看照片」** 按钮，打开只读照片弹层，展示车牌识别（Lrp）与现场抓拍（UrbanPhoto）两张图（有则显示，无则占位）。
- 将 UrbanManagement 服务端 `AttachType` 改为与 MaterialClient **完整枚举定义一致**（`UnmatchedEntryPhoto = 0`、`EntryPhoto = 1`、`ExitPhoto = 2`、`TicketPhoto = 3`、`Lrp = 5`、`UrbanPhoto = 6`），`AttachmentFile` 实体、EF、API 使用枚举而非字符串。
- UrbanManagement **业务仅使用** `Lrp` 与 `UrbanPhoto`：上传 API 仅接受此二值；附件读取与 Web 展示**仅处理并展示**这两种类型；其他枚举成员保留定义以供跨端数值对齐，本期不落库、不展示。
- 重构 `UrbanWeighingRecordApprovalAttachmentsDto` / `GetApprovalAttachmentsAsync`（或等价命名）为按枚举槽位返回图片，供审批弹层与「查看照片」弹层复用。
- **BREAKING**：`UrbanAttachmentUploadInputDto.AttachType` 由 `string` 改为枚举整型；MaterialClient.Urban 上传请求须同步改为发送 `5` / `6`（或枚举 JSON 序列化值）。

## Capabilities

### New Capabilities

- `urban-weighing-photo-view`: UrbanManagement Web 称重记录与异常审批页的只读照片查看（列表操作、弹层 UI、按 AttachType 枚举展示 Lrp / UrbanPhoto）。

### Modified Capabilities

- `attachment-file-storage`: `AttachType` 保留 MaterialClient 全量枚举定义；字段改为枚举存储；上传/落库仅接受 Lrp/UrbanPhoto；读取与 Web 展示按枚举分类。
- `blazor-weighing-record`: 增加「查看照片」操作；更新列表列定义（移除重试次数）。
- `independent-approval-page`: 增加「查看照片」操作；更新列表列定义（移除重试次数）；审批弹层复用统一附件 API。

## Impact

- **UrbanManagement**（`repos/UrbanManagement/`）
  - `Entities/AttachmentFile.cs`、`Entities/Enums/AttachType.cs`
  - `Services/FileService.cs`、`Services/UrbanAttachmentAppService.cs`、`Services/UrbanWeighingRecordAppService.cs`
  - `Models/UrbanWeighingRecordDtos.cs`、`Models/UrbanAttachmentUploadDtos.cs`
  - `Pages/WeighingRecord.razor`、`Pages/WeighingApproval.razor`
  - EF Core 迁移（`AttachType` 列 string → short/int）
- **MaterialClient.Urban**（`repos/MaterialClient/`）
  - `Dtos/UrbanAttachmentUploadDtos.cs`、`Services/UrbanAttachmentSyncService.cs`（上传 `attachType` 改为枚举值）
- **规范**：`attachment-file-storage`、`blazor-weighing-record`、`independent-approval-page` delta specs
