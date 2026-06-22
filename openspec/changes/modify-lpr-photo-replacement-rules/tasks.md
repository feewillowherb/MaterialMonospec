## 1. 服务端 — 审批 DTO

- [ ] 1.1 从 `UrbanWeighingRecordApproveInputDto` 中删除 `UrbanPhotoReplacementBase64` 属性
- [ ] 1.2 在 `UrbanWeighingRecordApproveInputDto` 上新增 `bool AdoptUrbanPhotoAsLpr` 属性（默认 `false`）

## 2. 服务端 — FileService 采纳路径

- [ ] 2.1 在 `IFileService` 上新增 `Task<Guid> AdoptUrbanPhotoAsLprAsync(Guid recordId)`
- [ ] 2.2 实现 `FileService.AdoptUrbanPhotoAsLprAsync`：通过注入的仓储加载记录当前的 `AttachType.UrbanPhoto` `AttachmentFile`（不得依赖 ViewModel）
- [ ] 2.3 在 `AdoptUrbanPhotoAsLprAsync` 中，从磁盘读取 UrbanPhoto 源文件，并以复制（非移动）方式走既有 `SaveAndCompressImagesAsync` 类似代码路径持久化为新的 `AttachmentFile(AttachType.Lrp)`
- [ ] 2.4 在 `AdoptUrbanPhotoAsLprAsync` 中，插入一条新的 `UrbanWeighingRecordAttachment` 关联表行，将新的 Lrp `AttachmentFile` 关联到该记录
- [ ] 2.5 确认 `AdoptUrbanPhotoAsLprAsync` 不会删除或修改原始 UrbanPhoto `AttachmentFile`、其关联表行或磁盘文件
- [ ] 2.6 为 `AdoptUrbanPhotoAsLprAsync` 增加保护：若记录已存在 `AttachType.Lrp` 附件，则以业务错误拒绝
- [ ] 2.7 为 `AdoptUrbanPhotoAsLprAsync` 增加保护：若记录不存在 `AttachType.UrbanPhoto` 附件，则以业务错误拒绝
- [ ] 2.8 为实现标注 `[UnitOfWork]`，使采纳动作参与调用方的事务

## 3. 服务端 — ApproveAsync 编排

- [ ] 3.1 从 `UrbanWeighingRecordAppService.ApproveAsync` 中移除 UrbanPhoto 替换分支（不再为 `AttachType.UrbanPhoto` 调用 `ReplaceAttachmentAsync`）
- [ ] 3.2 新增互斥校验：若 `LrpReplacementBase64` 非空 且 `AdoptUrbanPhotoAsLpr == true` 同时成立，以业务错误拒绝（或优先采用 Lrp 替换——二选一并在调用点写明注释）
- [ ] 3.3 新增采纳分支：当 `AdoptUrbanPhotoAsLpr == true` 时，调用 `IFileService.AdoptUrbanPhotoAsLprAsync(recordId)`
- [ ] 3.4 在调用 FileService 之前校验采纳前置条件：记录当前不存在 Lrp 附件 且 存在 UrbanPhoto 附件
- [ ] 3.5 更新 `EditEntry` 追加逻辑：在发生 Lrp 替换 **或** 采纳时，均沿用既有 `IsImagesModified` 标志将其置为 `true`；不新增任何编辑历史字段
- [ ] 3.6 确认审批的 UnitOfWork 原子性地包裹附件处理 + 记录更新 + 编辑历史追加

## 4. 客户端 — EditResult 结构

- [ ] 4.1 从 `repos/MaterialClient` 的 `EditResult` 中删除 `UrbanPhotoReplacementBase64`
- [ ] 4.2 在 `EditResult` 上新增 `bool AdoptedLpr`（默认 `false`）

## 5. 客户端 — 对话框 ViewModel

- [ ] 5.1 从 `WeighingRecordEditDialogViewModel` 中删除 `ReplaceUrbanPhotoCommand` 以及任何与 UrbanPhoto 替换相关的状态
- [ ] 5.2 在 `WeighingRecordEditDialogViewModel` 上新增 `AdoptUrbanPhotoAsLprCommand`（ReactiveCommand）
- [ ] 5.3 暴露可观察对象 `CanAdoptUrbanPhotoAsLpr`，仅当 `LprPhotoPath` 为 null/空 且 `CameraPhotoPath` 非空 时为 `true`；命令的启用绑定到它
- [ ] 5.4 实现 `AdoptUrbanPhotoAsLprCommand` 执行逻辑：读取 UrbanPhoto 源文件，用其字节更新 Lrp 预览，清除 Lpr 区域的 抓拍异常 指示，置 `EditResult.AdoptedLpr = true`，并清除任何已暂存的 `EditResult.LrpReplacementBase64`
- [ ] 5.5 确保 `ReplaceLrpCommand` 执行时清除 `EditResult.AdoptedLpr`（在 ViewModel 层实现互斥）
- [ ] 5.6 可选：提供「取消采纳」入口，将 `EditResult.AdoptedLpr` 还原为 `false`，并恢复 Lpr 占位图 + 抓拍异常 指示

## 6. 客户端 — 对话框视图

- [ ] 6.1 从 `WeighingRecordEditDialog.axaml` 中移除 UrbanPhoto 预览区域的 替换 按钮及其命令绑定
- [ ] 6.2 在 Lpr 预览区域添加「采纳为车牌照」按钮，绑定到 `AdoptUrbanPhotoAsLprCommand`
- [ ] 6.3 将「采纳为车牌照」按钮的 `IsVisible` 绑定到 `CanAdoptUrbanPhotoAsLpr`，确保在 Lpr 非空或 UrbanPhoto 缺失时隐藏
- [ ] 6.4 验证 UrbanPhoto 预览区域仍然渲染图片并支持点击打开 `ImageViewerWindow`，但不暴露任何替换入口

## 7. 客户端 — 审批协调器

- [ ] 7.1 更新 `UrbanAttendedWeighingViewModel.ApproveRecordAsync`，不再转发 `UrbanPhotoReplacementBase64`
- [ ] 7.2 更新 `ApproveRecordAsync`，将 `EditResult.AdoptedLpr` 作为 `AdoptUrbanPhotoAsLpr` 转发到 `UrbanWeighingRecordApproveInputDto`
- [ ] 7.3 确认 `LrpReplacementBase64` 仍然原样从 `EditResult` 转发到 DTO

## 8. 横切关注点 — 同步上线验证

- [ ] 8.1 手动验证客户端审批对话框不再提供 UrbanPhoto 替换
- [ ] 8.2 手动验证「采纳为车牌照」按钮仅在 Lpr 为空且 UrbanPhoto 存在时出现
- [ ] 8.3 手动验证暂存采纳的审批会在服务端生成新的 Lrp 附件，且 UrbanPhoto 附件保持不变
- [ ] 8.4 手动验证同时暂存 Lrp 替换与采纳的审批会被服务端拒绝
- [ ] 8.5 手动验证既有 `EditEntry.IsImagesModified` 标志在发生 Lpr 替换 **或** 采纳时均被持久化为 `true`（沿用既有语义，不区分替换来源）
