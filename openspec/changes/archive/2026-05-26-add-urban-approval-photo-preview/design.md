## Context

`WeighingRecordEditDialog` 由 `UrbanAttendedWeighingViewModel.ApproveRecordAsync` 打开，当前仅绑定 `PlateNumber` 与 `TotalWeight`。主界面 `UrbanAttendedWeighingViewModel` 已通过 `IAttachmentService.GetAttachmentsByWeighingRecordIdsAsync` 按 `WeighingRecordId` 解析 `AttachType.Lrp` 与 `AttachType.UrbanPhoto` 路径（`UpdatePhotoPathsAsync`），侧边栏使用 `OpenLprImageViewerCommand` / `OpenCameraImageViewerCommand` 打开 `MaterialClient.UI` 的 `ImageViewerWindow`。

审批场景应复用同一附件解析规则与查看器，避免重复业务逻辑或直连 Repository。

## Goals / Non-Goals

**Goals:**

- 审批对话框打开时自动加载并展示该记录的 LRP、UrbanPhoto 缩略图。
- 点击缩略图可全屏查看；路径缺失时显示占位、不崩溃。
- 对话框尺寸与布局可容纳预览区，仍保留车牌/重量编辑与确定/取消。

**Non-Goals:**

- 不在审批对话框内编辑、删除或上传附件。
- 不改变主界面侧边栏照片行为或 `photo-sidebar-viewer` 规范。
- 不实现 Urban 服务端远程审批 API（仍为本机 `UpdateWeighingRecordAsync`）。

## Decisions

### 1. 在 `WeighingRecordEditDialogViewModel` 内加载附件

**选择**：构造函数注入 `IAttachmentService`、`ILogger`，提供 `LoadPhotosAsync(long weighingRecordId)`，在对话框显示前由 `ApproveRecordAsync` 调用。

**理由**：与主 ViewModel 一致，符合「ViewModel → Service」约束；对话框生命周期短，无需把路径预先塞进 DTO。

**备选**：由 `UrbanAttendedWeighingViewModel` 预取路径再传入 — 减少重复查询但耦合打开方与列表选中状态；审批以 `item.WeighingRecordId` 为准，对话框自加载更清晰。

### 2. 附件类型映射

**选择**：`AttachType.Lrp` → `LprPhotoPath`；`AttachType.UrbanPhoto` → `CameraPhotoPath`（命名与主界面侧边栏一致，UI 文案为「车牌识别抓拍」「摄像头抓拍」）。

**理由**：与 `fix-urban-attachment-image-types` 及 `UpdatePhotoPathsAsync` 一致。

### 3. 全屏查看复用 `ImageViewerWindow`

**选择**：对话框 ViewModel 提供 `OpenLprImageViewerCommand` / `OpenCameraImageViewerCommand`，实现与 `UrbanAttendedWeighingViewModel` 相同（`IServiceProvider` 解析 `ImageViewerViewModel`，`Show()` 非模态）。

**理由**：已有 `photo-sidebar-viewer` 行为与 DI 注册；避免对话框内嵌第二套缩放逻辑。

### 4. 对话框布局

**选择**：加宽对话框（约 640×480），上/左为双列缩略图预览（各约 120px 高），下/右为车牌、重量与按钮。使用 `CarNullOrEmptyImageConverter` 绑定 `Image.Source`。

```
┌──────────────────────────────────────────────────────────────┐
│ 审批称重记录                                            [×] │
├────────────────────────────┬─────────────────────────────────┤
│ 车牌识别抓拍        12:01  │  车牌号:  [ 浙A12345      ]    │
│ ┌────────────────────────┐ │  重量(吨): [ 12.50         ]    │
│ │      [LRP 缩略图]      │ │                                 │
│ └────────────────────────┘ │                                 │
│ 摄像头抓拍          12:01  │                                 │
│ ┌────────────────────────┐ │                                 │
│ │   [UrbanPhoto 缩略图]  │ │                                 │
│ └────────────────────────┘ │                                 │
├────────────────────────────┴─────────────────────────────────┤
│                              [ 取消 ]  [ 确定 ]              │
└──────────────────────────────────────────────────────────────┘
```

### 5. ViewModel 注册

**选择**：`WeighingRecordEditDialogViewModel` 继续由 `new` 创建（与现有一致），通过构造函数注入 `IAttachmentService`；`ApproveRecordAsync` 从 `_serviceProvider` 解析服务后传入或让对话框 ViewModel 接收 `IServiceProvider` 仅用于 ImageViewer。

**理由**：对话框非单例屏幕，不必全局 DI 注册；若已注册为 transient 可改为 `GetRequiredService<WeighingRecordEditDialogViewModel>()` 并 `Initialize(recordId)` — 实现阶段二选一，优先构造函数注入 `IAttachmentService` + `IServiceProvider`。

## Risks / Trade-offs

- **[Risk] 对话框打开时附件查询略慢** → 加载期间缩略图显示占位；查询失败记日志，不阻塞编辑与保存。
- **[Risk] 非模态 ImageViewer 叠在模态 Dialog 上** → 与主界面行为一致；若 z-order 异常可后续改为 `ShowDialog` 子窗口。
- **[Risk] 重复实现 Open*ImageViewer 命令** → 可提取小型 helper/static 方法到 Urban 共享类；本变更先复制主 ViewModel 片段以保持范围小。

## Migration Plan

1. 实现并本地验证：有/无 LRP、有/无 UrbanPhoto、两者皆有、点击放大。
2. 无需数据库迁移。
3. 回滚：还原对话框 XAML/ViewModel 与 `ApproveRecordAsync` 传参即可。

## Open Questions

- 无。若产品要求审批对话框必须更大预览区，可在实现阶段仅调整 XAML 尺寸，不影响规范。
