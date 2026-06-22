## 1. UrbanManagement — 服务端 API（Web 审批）



- [x] 1.1 从 `UrbanWeighingRecordApproveInputDto` 移除 `UrbanPhotoReplacementBase64`（或标记 Obsolete 后移除）；保留 `LrpReplacementBase64` 供 Web 使用

- [x] 1.2 更新 `UrbanWeighingRecordAppService.ApproveAsync`：仅当 `LrpReplacementBase64` 非空时调用 `ReplaceAttachmentAsync(..., AttachType.Lrp, ...)`；忽略 legacy UrbanPhoto 替换字段

- [x] 1.3 更新 Web 审批历史逻辑：`IsImagesModified` 仅依据 `LrpReplacementBase64`

- [x] 1.4 补充或更新 Core 层单元测试：Web Lrp 替换/采纳、UrbanPhoto 字段被忽略



## 2. UrbanManagement — Web 审批 UI



- [x] 2.1 修改 `WeighingPhotoPreview.razor`：移除 UrbanPhoto 替换按钮、file input 与 `UrbanPhotoReplacementChanged`

- [x] 2.2 Web Lrp 区「采纳」：Lrp 空且 UrbanPhoto 有时，将 UrbanPhoto Base64 写入 pending `LrpReplacementBase64` 并触发 `LprReplacementChanged`

- [x] 2.3 更新 `WeighingApproval.razor`：移除 UrbanPhoto 替换状态；审批提交仅传 `LrpReplacementBase64`

- [x] 2.4 确认 UrbanPhoto 区只读



## 3. MaterialClient.Urban — 本地 Lrp 与采纳



- [x] 3.1 在 `IAttachmentService`（或等价 Service）实现 `CreateLrpFromUrbanPhotoAsync`：从 UrbanPhoto 文件复制/落盘创建 `AttachType.Lrp` 及关联；UrbanPhoto 不变

- [x] 3.2 实现/复用本地 Lrp 文件替换方法（file picker 选中后落盘并关联 weighing record）

- [x] 3.3 更新 `WeighingRecordEditDialogViewModel`：「采纳」调用 Service 创建本地 Lrp 并更新 `LprPhotoPath`；移除 `UrbanPhotoReplacementBase64`、`ReplaceUrbanPhotoCommand`

- [x] 3.4 从 MaterialClient `EditResult` 移除 `LrpReplacementBase64` 与 `UrbanPhotoReplacementBase64`

- [x] 3.5 更新 `WeighingRecordEditDialog.axaml`：UrbanPhoto 只读；Lrp 空且 UrbanPhoto 有时显示「采纳」

- [x] 3.6 对话框跟踪本次会话是否发生本地 Lrp 创建/替换，供修改历史使用



## 4. MaterialClient.Urban — 审批与上云

- [x] 4.1 **删除** `UrbanAttendedWeighingViewModel` 中 `await api.ApproveWeighingRecordAsync(...)` 整段调用
- [x] 4.2 审批确认后：`UpdateWeighingRecordAsync` + 本地 `EditHistory`；满足条件时 `PublishAsync(UrbanWeighingUploadRequestedEventData)`，**不**在 UI 线程 `await SubmitRecordAsync`
- [x] 4.3 从 `IUrbanManagementApi` 移除 `ApproveWeighingRecordAsync`（若存在）
- [x] 4.4 新增 `UrbanWeighingUploadRequestedEventData`（`MaterialClient.Common/Events/`）及 `UrbanWeighingUploadRequestedEventHandler`：UoW 内对单条记录调用 `SubmitRecordAsync`；成功发布 `UploadCompletedEventData`
- [x] 4.5 确认即时上云失败时 `SyncStatus` 仍为 `Pending`，`PollingBackgroundService` 可兜底重试；审批后新 Lrp 随 `SubmitRecordAsync` 上传

## 5. 验证

- [x] 5.1 Web：Lrp 替换/采纳经 `ApproveAsync`；UrbanPhoto 不可改
- [x] 5.2 MaterialClient：采纳后本地 Lrp；审批后**立即**触发单条上云（不必等轮询周期）；服务端收到 Lrp
- [x] 5.3 MaterialClient：不调用 `ApproveWeighingRecordAsync`；即时上云失败时轮询 Worker 仍能重试
- [x] 5.4 修改历史：`IsImagesModified` 正确；列表在 `UploadCompletedEventData` 后刷新
- [x] 5.5 运行 `openspec validate update-lpr-photo-replacement-rules --strict`

