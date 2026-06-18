## Why

审批环节中，Lrp 抓拍图与 UrbanPhoto 城市拍照一旦提交后无法纠正。抓拍失败、上传错误等异常图片只能整单驳回，审批效率低且缺少灵活的纠正手段。同时 Lrp 为空时前端没有明确的异常提示，用户无法区分"未抓拍到"和"正常无图"。修改历史中 `IsImagesModified` 字段虽已预留但从未被赋值，审批替换图片后无法追溯。

## What Changes

- 客户端（MaterialClient）审批编辑弹窗支持点击照片区域选择本地图片文件替换 Lrp / UrbanPhoto，替换后实时预览新图。
- 客户端将替换图片以 Base64 上传至服务端覆盖存储，旧图片文件直接舍弃不保留。
- 服务端（UrbanManagement）审批接口扩展接收可选的替换图片数据，执行图片替换（删除旧 AttachmentFile + 关联，写入新文件 + 关联），并在 EditHistory 中标记 `IsImagesModified = true`。
- 修改历史时间线中已有"图片已修改"徽章，替换图片后该徽章自动生效。
- 客户端与 UrbanManagement 服务端审批弹窗中，当 Lrp 图片路径为空时显示"抓拍异常"提示文案。

## Capabilities

### New Capabilities
- `approval-image-replacement`: 审批阶段图片替换能力——客户端本地图片选择与上传、服务端覆盖存储与关联更新、审批流程中图片替换的完整链路。

### Modified Capabilities
- `edit-history-tracking`: 激活 `EditEntry.IsImagesModified` 预留字段——审批替换图片时将其设为 `true`，使修改历史时间线正确展示"图片已修改"徽章。
- `urban-approval-photo-preview`: 在审批照片预览区域增加替换操作入口，以及 Lrp 为空时的"抓拍异常"异常指示。

## Impact

### UrbanManagement (服务端)

| 层 | 影响范围 |
|---|---|
| DTO | `UrbanWeighingRecordApproveInputDto` 新增 `LrpReplacementBase64?` 和 `UrbanPhotoReplacementBase64?` 可选字段 |
| Service | `UrbanWeighingRecordAppService.ApproveAsync` 增加图片替换逻辑：删除旧 Attachment + 关联，写入新 Attachment + 关联 |
| Service | `IFileService` 需新增 `ReplaceAttachmentAsync` 方法（删除旧文件 + 保存新文件） |
| Model | `EditEntry.IsImagesModified` 从预留字段变为活跃字段（代码层面无需结构变更，仅 ApproveAsync 赋值逻辑变更） |

### MaterialClient (客户端)

| 层 | 影响范围 |
|---|---|
| Dialog AXAML | `WeighingRecordEditDialog.axaml` 照片预览区域增加替换按钮覆盖层，Lrp 空时显示"抓拍异常" |
| ViewModel | `WeighingRecordEditDialogViewModel` 新增 `ReplaceLprCommand`、`ReplaceUrbanPhotoCommand`，文件选择与 Base64 编码逻辑 |
| DTO | `EditResult` 扩展携带替换图片 Base64 数据 |
| ViewModel | `UrbanAttendedWeighingViewModel` 审批流程中传递替换图片至服务调用 |

### 不影响

- 数据库 schema（AttachmentFile / 关联表结构不变，仅数据变更）
- 政府同步流程（同步读取逻辑不变）
- 非审批流程的图片上传（`UrbanAttachmentAppService.UploadAsync` 不变）

---

## Interaction Flow

```mermaid
flowchart TD
    A[操作员打开审批编辑弹窗] --> B{Lrp 是否为空?}
    B -- 是 --> C[显示 "抓拍异常" 提示]
    B -- 否 --> D[显示 Lrp 预览图]
    C --> E{操作员是否替换图片?}
    D --> E
    E -- 否 --> F[继续编辑车牌/重量]
    E -- 是 --> G[点击照片区域 → 弹出文件选择器]
    G --> H[选择本地图片文件]
    H --> I[客户端读取文件 → Base64 编码]
    I --> J[实时预览替换后的图片]
    J --> F
    F --> K[点击确定 → 二次确认]
    K --> L[客户端调用 ApproveAsync 携带替换图片]
    L --> M{服务端判断是否有替换图片}
    M -- 有 Lrp 替换 --> N[删除旧 Lrp Attachment + 关联]
    M -- 有 UrbanPhoto 替换 --> O[删除旧 UrbanPhoto Attachment + 关联]
    N --> P[保存新图片文件 + 创建 Attachment + 建立关联]
    O --> P
    P --> Q[设置 EditEntry.IsImagesModified = true]
    Q --> R[更新记录 → 清除异常 → 返回结果]
    R --> S[修改历史时间线显示 "图片已修改" 徽章]
    M -- 无替换图片 --> R
```

## ASCII Interface Prototype

### 客户端审批编辑弹窗 (替换后布局)

```
┌─ 审批称重记录 ──────────────────────────────────────────┐
│                                                          │
│  ┌──────────────┐  ┌─────────────────────────────────┐  │
│  │ 车牌识别抓拍  │  │  称重日期:  2024-01-15           │  │
│  │ 14:23:05     │  │                                 │  │
│  │ ┌──────────┐ │  │  车牌号:   [京A12345        ]   │  │
│  │ │          │ │  │                                 │  │
│  │ │  预览图   │ │  │  重量(吨): [25.60           ]   │  │
│  │ │          │ │  │                                 │  │
│  │ └──────────┘ │  └─────────────────────────────────┘  │
│  │  [📷 替换]   │                                      │
│  └──────────────┘                                      │
│  ┌──────────────┐                                      │
│  │ 摄像头抓拍    │                                      │
│  │ 14:23:08     │                                      │
│  │ ┌──────────┐ │                                      │
│  │ │          │ │                                      │
│  │ │  预览图   │ │                                      │
│  │ │          │ │                                      │
│  │ └──────────┘ │                                      │
│  │  [📷 替换]   │                                      │
│  └──────────────┘                                      │
│                                                          │
│                              [取消]  [确定]               │
└──────────────────────────────────────────────────────────┘
```

### Lrp 为空时状态

```
┌──────────────┐
│ 车牌识别抓拍  │
│              │
│ ┌──────────┐ │
│ │          │ │
│ │  占位图   │ │  ← CarNullOrEmptyImageConverter 默认车图
│ │          │ │
│ └──────────┘ │
│ ⚠ 抓拍异常   │  ← 新增异常提示
│  [📷 替换]   │
└──────────────┘
```

## Change Map

### UrbanManagement 代码变更清单

| 文件 | 变更原因 | 变更类型 |
|------|---------|---------|
| `Core/Models/UrbanWeighingRecordDtos.cs` | `UrbanWeighingRecordApproveInputDto` 新增替换图片 Base64 字段 | 修改 |
| `Core/Services/UrbanWeighingRecordAppService.cs` | `ApproveAsync` 增加图片替换分支逻辑、设置 `IsImagesModified` | 修改 |
| `Core/Services/IFileService.cs` | 新增 `ReplaceAttachmentAsync` 方法签名 | 修改 |
| `Core/Services/FileService.cs` | 实现 `ReplaceAttachmentAsync`（删除旧文件+关联、保存新文件+关联） | 修改 |
| `App/Pages/WeighingApproval.razor` | 审批弹窗照片预览区增加替换入口、Lrp 空时显示异常提示、传递替换图片到审批调用 | 修改 |
| `App/Pages/Components/WeighingPhotoPreview.razor` | 增加替换按钮、Lrp 空异常提示展示 | 修改 |

### MaterialClient 代码变更清单

| 文件 | 变更原因 | 变更类型 |
|------|---------|---------|
| `Urban/Views/Dialogs/WeighingRecordEditDialog.axaml` | 照片预览区增加替换按钮、Lrp 空异常提示 | 修改 |
| `Urban/ViewModels/WeighingRecordEditDialogViewModel.cs` | 新增替换命令、文件选择器交互、Base64 编码、实时预览更新 | 修改 |
| `Urban/ViewModels/UrbanAttendedWeighingViewModel.cs` | 审批流程中传递替换图片数据 | 修改 |
