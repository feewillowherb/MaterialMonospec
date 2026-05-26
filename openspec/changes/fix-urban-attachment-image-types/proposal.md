## Why

Urban 称重记录在创建 `AttachmentFile` 时，所有抓拍图片均写为 `AttachType.UnmatchedEntryPhoto`，与 UI 及规范预期不符：车牌识别图应为 `Lrp`，海康监控抓拍应为独立的城管专用类型。导致 `UrbanAttendedWeighingViewModel` 无法正确展示 LRP 与相机照片（当前按 `Lrp` / `EntryPhoto` 查询，但库中类型错误）。

## What Changes

- 新增 `AttachType.UrbanPhoto` 枚举值，用于存储 Urban 模式下海康相机称重抓拍图片
- 修复 `WeighingRecordService.SaveCapturePhotosAsync`：UrbanMode 下 Hik 抓拍保存为 `UrbanPhoto`；非 Urban 模式保持 `UnmatchedEntryPhoto`
- 称重记录创建时，将当前周期内已保存的 LRP 图片路径关联为 `AttachmentFile`，`AttachType` 必须为 `Lrp`
- 更新 `WeighingCaptureService`：UrbanMode 下抓拍存储目录/路径与 `UrbanPhoto` 类型一致
- 更新 `AttachmentPathUtils`：为 `UrbanPhoto`、`Lrp` 提供正确的本地/OSS 路径映射
- 更新 `UrbanAttendedWeighingViewModel`：相机侧栏按 `UrbanPhoto` 加载（不再误用 `EntryPhoto`）
- 确保 OSS 上传 `bizType` 映射包含 `UrbanPhoto`（若存在集中映射表则一并更新）

## Capabilities

### New Capabilities

（无新增独立 capability；`UrbanPhoto` 作为 `AttachType` 扩展纳入既有 Urban 附件能力。）

### Modified Capabilities

- `materialclient-urban-desktop`：明确 Lrp 与 UrbanPhoto 在称重落库时的 `AttachType` 及 UI 绑定规则
- `attended-weighing`：UrbanMode 下抓拍附件类型与 Lrp 关联行为
- `weighing-device-capture`：UrbanMode 下抓拍存储路径使用 `UrbanPhoto`

## Impact

- **子仓库**：`repos/MaterialClient`（`MaterialClient.Common`、`MaterialClient.Urban`）
- **核心文件**：
  - `Entities/Enums/AttachType.cs`
  - `Utils/AttachmentPathUtils.cs`
  - `Services/AttendedWeighing/WeighingRecordService.cs`
  - `Services/AttendedWeighing/WeighingCaptureService.cs`
  - `Services/AttendedWeighing/AttendedWeighingService.cs`（若需传递 Lrp 路径）
  - `Urban/ViewModels/UrbanAttendedWeighingViewModel.cs`
  - `Services/AttachmentService.cs` / `OssUploadService.cs`（如有 bizType 映射）
- **数据**：已有错误类型的历史记录不在本变更自动修复范围内（可选后续数据修复脚本）
- **UrbanManagement**：无直接影响（枚举值扩展，同步协议若依赖 bizType 需确认后端是否需登记新类型）
