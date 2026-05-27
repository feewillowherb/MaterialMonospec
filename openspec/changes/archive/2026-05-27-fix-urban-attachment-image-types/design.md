## Context

Urban 称重流程在 `WeightStabilized` 时调用 `WeighingCaptureService.CaptureAllCamerasAsync` 获取海康 JPEG 路径，再由 `WeighingRecordService.SaveCapturePhotosAsync` 写入 `AttachmentFile`。当前实现**一律**使用 `AttachType.UnmatchedEntryPhoto`，与 `UrbanAttendedWeighingViewModel`（按 `Lrp` / `EntryPhoto` 查询）及 `materialclient-urban-desktop` 规范不一致。

LRP 图片已在 `HikvisionLprService` / `VzvisionLprService` 的 `TrySaveLrpAttachment` 中落盘，并通过 `LicensePlateRecognizedEventData.LrpImagePath` 传出，但 `AttendedWeighingService` 订阅 LPR 事件时**未保存**该路径，也**未**在创建称重记录时写入 `AttachmentFile(AttachType.Lrp)`。

## Goals / Non-Goals

**Goals:**

- 新增 `AttachType.UrbanPhoto`，专用于 Urban 海康称重抓拍
- UrbanMode 落库：抓拍 → `UrbanPhoto`；当前周期 LRP 图 → `Lrp`
- 路径工具与抓拍服务在 UrbanMode 下使用正确目录
- Urban UI 按 `UrbanPhoto` 显示相机照片

**Non-Goals:**

- 不修复历史库中错误 `AttachType` 的数据（可选后续脚本）
- 不改变非 Urban 模式的附件类型策略（仍为 `UnmatchedEntryPhoto`）
- 不修改 UrbanManagement 后端（除非后续同步协议明确要求新 bizType）

## Decisions

### 1. 枚举值：`UrbanPhoto = 6`

- **选择**：`UrbanPhoto = 6`（`Lrp = 5` 已占用，跳过未使用的 4 以保持与现网一致）
- **理由**：与现有 DB `short` 列兼容，无需 EF 结构迁移
- **替代**：复用 `EntryPhoto` — 与标准模式语义冲突，且 UI 无法区分城管抓拍

### 2. 落库职责集中在 `WeighingRecordService`

- **选择**：扩展 `CreateWeighingRecordAsync` / `SaveCapturePhotosAsync`，根据 `WeighingMode` 选择 `AttachType`；新增 `SaveLrpAttachmentAsync(recordId, relativePath)` 或在同一 UoW 内写入 Lrp
- **理由**：附件与 `WeighingRecord` 的关联已在此服务；符合 ViewModel → Service 分层
- **替代**：在 LPR 服务内直接写库 — 此时尚无 `WeighingRecordId`，时序复杂

### 3. 当前周期 LRP 路径由 `WeighingStateManager` 持有

- **选择**：在 `WeighingStateManager` 增加 `CurrentCycleLrpImagePath`（相对路径），`AttendedWeighingService` 处理 `LicensePlateRecognizedEventData` 时更新（有 `LrpImagePath` 则覆盖）；`ResetCycle` 时清空
- **理由**：与「每车一次称重周期」生命周期一致；不污染 `PlateNumberService` 职责
- **替代**：在 `CreateWeighingRecordAsync` 参数中传入 — 需改接口链，侵入面更大

### 4. 存储路径

| AttachType   | 本地根目录（相对 AppBase） | 说明 |
|-------------|---------------------------|------|
| `Lrp`       | `Lrp/`（已有）            | 与 `TrySaveLrpAttachment` 一致 |
| `UrbanPhoto`| `PhotoUrban/{yyyy}/{MM}/{dd}/` | 与 `PhotoJianKong` 平级，便于区分城管抓拍 |
| 其他模式抓拍 | `PhotoJianKong/...` + `UnmatchedEntryPhoto` | 不变 |

- **选择**：在 `AttachmentPathUtils.GetBasePath` 中为 `Lrp`、`UrbanPhoto` 分支；`WeighingCaptureService` UrbanMode 下调用 `GetLocalStorageAbsolutePath(AttachType.UrbanPhoto, ...)`
- **理由**：抓拍路径与落库类型一致，避免文件在 `PhotoJianKong` 而库中为 `UrbanPhoto`

### 5. UI 绑定

- **选择**：`UrbanAttendedWeighingViewModel.UpdatePhotoPathsAsync` 将相机照片条件由 `EntryPhoto` 改为 `UrbanPhoto`
- **理由**：与落库类型对齐；`EntryPhoto` 保留给标准/固废有人值守语义

## Risks / Trade-offs

- **[Risk] 周期内多次 LRP 识别，路径被覆盖** → 取最后一次识别图（与当前 plate 缓存策略一致）；日志记录路径变更
- **[Risk] 称重时无 LRP 图（识别失败或未配置）** → 仅保存 `UrbanPhoto`，不创建 Lrp 附件；UI 显示空 LRP 区
- **[Risk] OSS `bizType` 未登记 UrbanPhoto** → 实现时检查 `AttachmentService` / 上传映射，与 `Lrp` 同样使用 `(int)AttachType`；若后端拒绝新值，记入 Open Questions
- **[Risk] 旧记录仍为错误类型** → 仅影响历史数据展示；本变更不迁移

## Migration Plan

1. 部署新版本 MaterialClient.Urban + Common
2. 新称重记录自动使用正确类型
3. 回滚：还原枚举与落库逻辑（新 `UrbanPhoto` 记录可保留，旧客户端可能无法识别显示）

## Open Questions

- Urban 数据同步至 UrbanManagement 时，`UrbanPhoto` / `Lrp` 的 `bizType` 是否已在服务端白名单？若否，需后续 change 协调后端。
