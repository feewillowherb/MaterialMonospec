## Why

当前审批流程允许同时替换 Lrp（车牌识别）与 UrbanPhoto（枪机抓拍）图片，但业务上枪机抓拍应作为原始现场证据保留，不应被人工替换。同时，当 Lrp 抓拍异常（为空）而 UrbanPhoto 存在时，审批人员需要一种快捷方式将枪机图片采纳为 Lrp 图片，而不必再从本地选择文件。修改历史只需标记「图片已修改」，无需区分「替换」与「采纳」来源。

## What Changes

- **BREAKING**：移除 `UrbanPhotoReplacementBase64` 审批入参及所有 UrbanPhoto 替换逻辑；UrbanPhoto 在审批 UI 中改为只读预览，不提供替换按钮。
- 仅 Lrp 照片支持图片修改：通过本地文件选择器替换，或在 Lrp 为空且 UrbanPhoto 非空时通过「采纳」将 UrbanPhoto 图片创建为新的 Lrp 附件。
- **Web 端（UrbanManagement）**：审批提交时通过 `LrpReplacementBase64` 调用 `ApproveAsync` → `ReplaceAttachmentAsync(AttachType.Lrp)`；采纳与文件替换均走该字段。
- **客户端（MaterialClient.Urban）**：审批确认后 `UpdateWeighingRecordAsync`（plate/weight、异常、修改历史、`SyncStatus = Pending`），随后通过 **`ILocalEventBus` 发布单条上云请求事件**，由后台 Handler **立即**对该记录调用 `SubmitRecordAsync`（附件 upload + `ReceiveAsync`）；**不在 UI 线程**直接调 HTTP。`PollingBackgroundService` 仍保留，作为失败重试与批量 Pending 扫描的兜底。
- **BREAKING（客户端）**：移除 `UrbanAttendedWeighingViewModel` 中对 `ApproveWeighingRecordAsync` / `ApproveAsync` 的调用；客户端 Refit **不**使用审批专用 Approve 端点。plate/weight/附件同步走 `ReceiveAsync` 去重 upsert（见 `update-client-approval-server-sync`）。
- **Web 端 `ApproveAsync` 保留**：仅供 `/weighing-approval` 管理员在服务端直接审批；与客户端路径无关。
- 修改历史（`EditHistoryJson` / `IsImagesModified`）在任意 Lrp 图片修改（含采纳）时标记为已修改图片，不记录采纳/替换类型区分。

## Capabilities

### New Capabilities

（无新增 capability；行为变更均在现有 capability 内完成。）

### Modified Capabilities

- `approval-image-replacement`：限制替换范围至 Lrp；Web 经 `LrpReplacementBase64`；客户端本地落盘 + 上云；移除 UrbanPhoto 替换。
- `urban-approval-photo-preview`：UrbanPhoto 只读；Lrp 区「采纳」；客户端采纳为本地创建 Lrp。
- `urban-client-attachment-sync`：审批后新增/变更的本地 Lrp 随 Pending 上云。
- `urban-polling-background-service`：新增审批后单条立即上云事件与 Handler；轮询 Worker 仍为兜底。
- `weighing-record-approval`：客户端审批移除 `ApproveWeighingRecordAsync`；本地更新后发布上云事件。
- `urban-weighing-api`：明确 `ApproveAsync` 为 Web 专用 API，客户端不得调用。
- `edit-history-tracking`：`IsImagesModified` 仅 Lrp 修改；Web 与客户端各自触发路径。
- `urbanmanagement-weighing-record-approval`：Web 审批 API 与 UI 规则。

## Impact

- **UrbanManagement**：`UrbanWeighingRecordApproveInputDto`、`UrbanWeighingRecordAppService.ApproveAsync`、`WeighingPhotoPreview.razor`、`WeighingApproval.razor`。
- **MaterialClient.Urban**：`UrbanAttendedWeighingViewModel`（审批后发布 `UrbanWeighingUploadRequestedEventData`）、新增 `ILocalEventHandler` 立即上云 Handler、`IUrbanServerUploadService` / `PollingBackgroundService`（兜底轮询）。
- **Specs**：`approval-image-replacement`、`urban-approval-photo-preview`、`edit-history-tracking`、`urbanmanagement-weighing-record-approval`、`weighing-record-approval`、`urban-weighing-api`、`urban-polling-background-service` delta 更新。
- **兼容性**：若旧客户端仍提交 `UrbanPhotoReplacementBase64`，服务端应忽略该字段（不报错、不修改 UrbanPhoto）。
