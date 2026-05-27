## Why

城管有人值守称重在审批称重记录时，操作员需要对照车牌识别（LRP）与海康抓拍（UrbanPhoto）核对车牌与重量后再确认。当前 `WeighingRecordEditDialog` 仅提供车牌号与重量编辑，无法在审批界面预览附件，必须关闭对话框回到主界面侧边栏查看，流程割裂且易误判。

## What Changes

- 扩展 `WeighingRecordEditDialogViewModel`：打开审批对话框时按 `WeighingRecordId` 加载 `AttachType.Lrp` 与 `AttachType.UrbanPhoto` 本地路径（及可选拍摄时间）。
- 扩展 `WeighingRecordEditDialog` UI：在表单旁或上方展示 LRP、UrbanPhoto 缩略图预览；无附件时显示占位图。
- 支持点击缩略图打开已有 `ImageViewerWindow` 全屏查看（标题与主界面侧边栏一致）。
- `UrbanAttendedWeighingViewModel.ApproveRecordAsync` 创建对话框 ViewModel 时传入 `WeighingRecordId` 并触发加载（异步初始化）。

## Capabilities

### New Capabilities

- `urban-approval-photo-preview`: 审批对话框内展示并点击查看 LRP 与 UrbanPhoto 附件预览。

### Modified Capabilities

- （无）主界面 `photo-sidebar-viewer` 行为不变；审批对话框为独立能力，不修改其需求。

## Impact

- **子仓库**：`repos/MaterialClient`
  - `MaterialClient.Urban/ViewModels/WeighingRecordEditDialogViewModel.cs`
  - `MaterialClient.Urban/Views/Dialogs/WeighingRecordEditDialog.axaml(.cs)`
  - `MaterialClient.Urban/ViewModels/UrbanAttendedWeighingViewModel.cs`（传入 record id）
- **依赖**：复用 `IAttachmentService`、`AttachType.Lrp` / `AttachType.UrbanPhoto`、`ImageViewerWindow` / `CarNullOrEmptyImageConverter`（与主界面一致）。
- **架构**：ViewModel 经 Service 访问附件，不直接注入 Repository。
