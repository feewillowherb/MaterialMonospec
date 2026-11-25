# 06 - 海康 LPR 双图（全景 + 车牌）上传现状与目标

创建日期：2026-11-25。生命周期：`ACTIVE`。知识状态：代码现状为 `CONFIRMED`；目标与范围已与用户确认（仅记录现状与 Goal，**暂不进 `docs/intake/` 与 `openspec/`**，不修改业务代码）。

---

## 1. 业务目标（Goal）

- **全业务统一上传双图**：新客户端（`MaterialClient.Urban` / `MaterialClient.Recycle`）在 **称重记录、卡口进出、成品进出** 三类业务中，统一将 LPR 识别返回的两张照片——**full（全景/场景图）** 与 **车牌（特写小图）**——全部上传至 `UrbanManagement` 并在 Admin 照片弹窗中展示。
- **设备范围边界**：
  - **海康（Hikvision）**：必须同时提取、保存并上传全景图与车牌图。
  - **臻识（Vzvision）**：允许无独立车牌小图，缺省时可省略（仅传已有图片，不阻断主流程）。

---

## 2. 现状核对（`CONFIRMED`）

| 链路环节 | 当前实现 | 存在缺口 | 源码定位 |
|----------|----------|----------|----------|
| **海康 SDK 回调提取** | 遍历 `itsResult.struPicInfo`，只取 `byType == HikItsPictureTypeScene`（场景全景图）后即 `break` | 未提取车牌特写图（`byType == 0` 等车牌小图类型） | `repos/MaterialClient/src/MaterialClient.Common/Services/Hikvision/HikvisionLprService.cs:477-490` |
| **本地事件传递** | `LicensePlateRecognizedEventData` 仅包含单个 `LprImagePath` 字段 | 无法同时传递全景图与车牌图两份路径 | `repos/MaterialClient/src/MaterialClient.Common/Events/LicensePlateRecognizedEventData.cs:51-55` |
| **通行记录本地落库** | `UrbanPassageRecord` 表与 `UrbanLprCaptureContext` 已有 `LargeImageAttachmentId` 和 `SmallImageAttachmentId` 两列 | `UrbanPassageLprHandler` 构造上下文时将 `SmallImageAttachmentId` 硬编码传 `null`；`UrbanPassageRecordService` 查询时也只取 `LargeImageAttachmentId` | `repos/MaterialClient/src/MaterialClient.Common.Urban/Services/Urban/UrbanPassageLprHandler.cs:66-76`、`UrbanPassageRecordService.cs:139, 159` |
| **称重记录本地落库** | `AttachmentService` / `WeighingRecordService` 按单个 `AttachType.Lpr` 覆盖或取 `FirstOrDefault` | 单条称重记录无法同时绑定全景与车牌两张 LPR 附件（或需区分角色/类型） | `repos/MaterialClient/src/MaterialClient.Common/Services/AttachmentService.cs:399-403`、`WeighingRecordService.cs:351, 415` |
| **Admin 照片展示** | `WeighingPhotoDialog.razor` 与 `PassagePhotoDialog.razor` 均已使用多图组件 `MultiImageGallery` | 前端画廊已支持多图，但需确认双图上传后的标签区分（如「车牌全景」「车牌特写」）与接口返回顺序 | `repos/UrbanManagement/src/UrbanManagement.Admin/Pages/Components/WeighingPhotoDialog.razor:71-77`、`PassagePhotoDialog.razor:27-31` |

---

## 3. 后续进入设计阶段时的关键决策点（预留）

当前不展开代码修改，后续正式立项时需敲定：

1. **附件类型与语义建模**：是在 `AttachType` 中区分全景/车牌小图，还是保持 `AttachType.Lpr` 并通过角色/文件名区分（需兼顾老客户端与既有政府同步接口兼容性）。
2. **上传与重试链路**：确认称重附件上传（Tus / `AttachmentIds`）与通行记录上传接口（卡口/成品进出）均支持携带双图 `AttachmentId`，且单图缺失（如 Vzvision 或海康偶发无小图）时平滑降级为单图上传。
3. **Admin 展示文案**：在 `WeighingPhotoDialog` 与 `PassagePhotoDialog` 中清晰标注「全景图」与「车牌图」，避免笼统显示「照片 1 / 照片 2」。
