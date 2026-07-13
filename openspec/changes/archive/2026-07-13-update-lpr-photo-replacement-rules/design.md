## Context



`approval-image-replacement-capture-anomaly` 变更已在 MaterialClient 与 UrbanManagement 实现 Lrp / UrbanPhoto 双通道替换：审批 DTO 含 `LrpReplacementBase64` 与 `UrbanPhotoReplacementBase64`，UI 各提供「替换」按钮，服务端 `IFileService.ReplaceAttachmentAsync` 按 `AttachType` 原子替换。



业务反馈：UrbanPhoto 为现场原始抓拍，审批时不应被替换；Lrp 缺失时常见补救是从已有 UrbanPhoto 补建 Lrp。MaterialClient 已有本地附件存储与 `urban-client-attachment-sync` 上云链路（`SubmitRecordAsync` → 附件 upload API → `ReceiveWeighingRecordAsync`），客户端审批本身不调用 `ApproveAsync`，而是通过重置 `SyncStatus = Pending` 触发后台上云。



## Goals / Non-Goals



**Goals:**



- 仅 Lrp 支持审批期图片修改（文件替换 + 采纳 UrbanPhoto）。

- UrbanPhoto 审批 UI 只读（可预览、可放大，无替换/采纳操作）。

- **Web**：Lrp 为空且 UrbanPhoto 非空时「采纳」，提交 `LrpReplacementBase64` 至 `ApproveAsync`。

- **MaterialClient**：「采纳」在本地以 UrbanPhoto 文件创建 `AttachType.Lrp` 附件，审批确认后由上云链路上传；文件替换同样本地落盘后上云。

- 修改历史统一以 `IsImagesModified = true` 表示 Lrp 图片被修改，不区分采纳与替换。



**Non-Goals:**



- 不改变 UrbanPhoto 上传、同步、存储路径规则。

- 不删除 `ReplaceAttachmentAsync` 对其它 `AttachType` 的通用能力（Web 审批仍使用 Lrp 路径）。

- 不在修改历史中增加新字段或文案区分采纳/替换。

- 不让 MaterialClient 在审批 **UI 命令路径**上同步 `await` UrbanManagement HTTP；审批后通过 `ILocalEventBus` 触发后台立即上云。`PollingBackgroundService` 保留为兜底。



## Decisions



### 1. 双端分流：Web 走 `ApproveAsync`，客户端走本地附件 + 上云



**选择**：



| 端 | 采纳 | 文件替换 Lrp | 同步至服务端 |

|----|------|-------------|-------------|

| **UrbanManagement Web** | UI 将 UrbanPhoto Base64 写入 pending `LrpReplacementBase64` | 文件 picker → `LrpReplacementBase64` | `ApproveAsync` → `ReplaceAttachmentAsync(Lrp)` |

| **MaterialClient.Urban** | 本地 `IAttachmentService` 从 UrbanPhoto 复制/落盘创建 Lrp | 本地保存/替换 Lrp 附件文件 | `UpdateWeighingRecordAsync` → 发布 `UrbanWeighingUploadRequestedEventData` → Handler 立即 `SubmitRecordAsync`；失败时 `PollingBackgroundService` 兜底 |



**理由**：客户端称重记录与附件本就本地权威，上云已有成熟链路；`approval-image-replacement-capture-anomaly` 中经 `ApproveWeighingRecordAsync` 传 Base64 的实现与 `weighing-record-approval`、`update-client-approval-server-sync` 冲突，应回退。

### 1b. 移除客户端 `ApproveWeighingRecordAsync` 整段调用

**选择**：删除 `UrbanAttendedWeighingViewModel` 中对 `ApproveWeighingRecordAsync` 的调用（含 `ClientRecordId`、`PlateNumber`、`TotalWeight`、`LprReplacementBase64`、`UrbanPhotoReplacementBase64`）。从 `IUrbanManagementApi` 移除 Approve Refit 方法（若已添加）。

客户端审批确认后：

1. `UpdateWeighingRecordAsync`（本地 plate/weight、异常、`SyncStatus = Pending`、本地 `EditHistory`）
2. `ILocalEventBus.PublishAsync(new UrbanWeighingUploadRequestedEventData { WeighingRecordId = ... })`（不 await HTTP）
3. `UrbanWeighingUploadRequestedEventHandler` 在后台对**该条**记录调用 `SubmitRecordAsync`（附件 upload + `ReceiveAsync`）
4. 若步骤 3 失败或未触发，`PollingBackgroundService` 在后续轮询中兜底重试

**理由**：`ApproveAsync` 供 Web 按服务端 `Id` 审批；客户端 plate/weight 已由 `ReceiveAsync` upsert 同步，再调 Approve 属双写。立即上云事件缓解纯轮询延迟，且不在 UI 命令路径上阻塞 HTTP。

**备选**：保留 Approve 仅传 plate/weight — 与 `ReceiveAsync` 重复，拒绝。

### 2. 客户端「采纳」：本地创建 Lrp，审批确认后上云



**选择**：点击「采纳」时立即调用 Service 层方法（如 `CreateLrpFromUrbanPhotoAsync(weighingRecordId)`）：



1. 读取该记录 UrbanPhoto 附件的 `LocalPath`（归一化绝对路径）。

2. 复制图像至 Lrp 存储路径（可复用现有 Lrp 压缩/命名规则）。

3. 创建 `AttachmentFile`（`AttachType.Lrp`）及 `WeighingRecordAttachment` 关联；若已有 Lrp 则先删旧（采纳场景通常无 Lrp）。

4. 更新对话框 `LprPhotoPath` 预览；**不**修改 UrbanPhoto 行或文件。

5. 操作员确认审批后：`UpdateWeighingRecordAsync` 写 plate/weight、追加 `EditHistory`（`IsImagesModified = true`）、`SyncStatus = Pending`；发布 `UrbanWeighingUploadRequestedEventData` 触发立即上云。

6. Handler（或兜底 Worker）`SubmitRecordAsync` 将新 Lrp 与其他附件 upload，并在 `ReceiveAsync` 携带 `attachmentIds`。



**备选**：采纳仅预览、确认时才落盘 — 未采纳；取消审批会丢失预览状态，且与「采纳即创建 Lrp」的产品语义不符。



### 3. 客户端文件替换 Lrp：同样本地落盘 + 上云



**选择**：文件 picker 选中后，Service 层替换/创建本地 Lrp 附件（与采纳共用「本地 Lrp 变更」路径），**不**填充 `EditResult.LrpReplacementBase64`。



**理由**：与采纳、现有 `urban-client-attachment-sync` 一致；避免客户端双通道（本地 + ApproveAsync Base64）。



### 4. Web 仍复用 `LrpReplacementBase64`（含采纳）



**选择**：Web 无本地附件库，采纳与文件替换均写入 `LrpReplacementBase64`，由 `ApproveAsync` 处理。



### 5. **BREAKING** 移除 UrbanPhoto 替换



**选择**：双端移除 UrbanPhoto 替换 UI 与 `UrbanPhotoReplacementBase64` 处理；legacy 字段服务端忽略。



### 6. 修改历史



**Web**：`ApproveAsync` 在 `LrpReplacementBase64` 非空时 `IsImagesModified = true`。



**MaterialClient**：`AppendEditEntryAsync` / 审批写历史时，若本次审批发生本地 Lrp 创建或替换，`IsImagesModified = true`；不区分采纳/替换。



### 7. UI 按钮矩阵（双端展示一致，底层实现不同）



| Lrp 状态 | UrbanPhoto 状态 | Lrp 区操作 | UrbanPhoto 区 |

|---------|----------------|-----------|---------------|

| 有图 | 任意 | 「替换」 | 只读 |

| 空 | 有图 | 「替换」+ 「采纳」 | 只读 |

| 空 | 空 | 「替换」 | 只读 |

### 8. 审批后立即上云事件

**选择**：

- 事件：`UrbanWeighingUploadRequestedEventData`（`WeighingRecordId`），置于 `MaterialClient.Common/Events/`。
- 发布：`UrbanAttendedWeighingViewModel` 在审批本地持久化成功且 `IsAnomaly == false`、`SyncStatus == Pending` 后 `PublishAsync`。
- 处理：`UrbanWeighingUploadRequestedEventHandler` 在 UoW 内调用 `SubmitRecordAsync(weighingRecordId)`；成功发布 `UploadCompletedEventData`。
- 兜底：`PollingBackgroundService` 继续扫描 Pending；即时上云失败时由轮询重试。

**理由**：采纳/替换 Lrp 后操作员期望尽快在服务端可见；纯轮询（默认 10 分钟）体验差。

**备选**：ViewModel `Task.Run(SubmitRecordAsync)` — 不符合 ABP Handler/UoW 模式，拒绝。

## Risks / Trade-offs



- **[Risk] 客户端采纳后、上云前服务端仍无 Lrp** → 审批后发布立即上云事件缓解；若即时上云失败，轮询 Worker 兜底重试。

- **[Risk] 本地复制 UrbanPhoto 失败（文件缺失）** → Service 层校验并提示；审批 Save 可阻断或允许仅改 plate/weight（以实现时 UX 为准，建议 adopt 失败则不禁用 Save 但提示 Lrp 未创建）。

- **[Risk] 上云时服务端已有旧 attachmentIds** → `ReceiveAsync` 更新逻辑须用新 upload Guids；依赖现有 re-upload after approval 行为。

- **[Trade-off] Web 与客户端实现路径不同** → 文档与 spec 明确分流，避免实现时混用 API。



## Migration Plan



1. 部署服务端：Web `ApproveAsync` 仅处理 `LrpReplacementBase64`；忽略 UrbanPhoto 替换字段。

2. 部署 Web UI：采纳/替换经 `LrpReplacementBase64`。

3. 发布 MaterialClient：本地 Lrp 创建/替换 + 上云；**删除** `ApproveWeighingRecordAsync` 调用及 Refit Approve 方法；`EditResult` 不再携带图片 Base64。

4. 无需数据库迁移。



## Open Questions



（无。）


