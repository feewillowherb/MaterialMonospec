## 1. UrbanManagement — AttachType 枚举对齐

- [ ] 1.1 扩展 `Entities.Enums.AttachType` 为与 MaterialClient 完整一致的全量定义（0/1/2/3/5/6）；将 `AttachmentFile.AttachType` 从 `string` 改为该枚举，更新 `UrbanManagementDbContext` 映射
- [ ] 1.2 新增 EF 迁移：列类型 `nvarchar` → `smallint`，数据映射 `Lrp`→5、`UrbanPhoto`→6
- [ ] 1.3 更新 `FileService.SaveAndCompressImagesAsync` 参数与校验为 `AttachType` 枚举；`GetApprovalAttachmentImagesAsync` 按枚举比较分类
- [ ] 1.4 更新 `UrbanAttachmentUploadInputDto.AttachType` 为枚举；`UrbanAttachmentAppService` 校验仅 `Lrp`/`UrbanPhoto`
- [ ] 1.5 更新 `UrbanWeighingRecordApprovalAttachmentsDto` 文档注释，明确按 `AttachType.Lrp` / `AttachType.UrbanPhoto` 槽位返回

## 2. MaterialClient.Urban — 上传 API 同步

- [ ] 2.1 将 `UrbanAttachmentUploadRequestDto.AttachType` 改为 `short` 或 `AttachType` 枚举（值 5/6）
- [ ] 2.2 更新 `UrbanAttachmentSyncService`：移除 `ToServerAttachTypeName`，直接发送枚举整型
- [ ] 2.3 确认 Refit JSON 序列化与 ABP 反序列化兼容（联调上传 Lrp / UrbanPhoto）

## 3. UrbanManagement — Web 查看照片 UI

- [ ] 3.1 抽取共享照片弹层（如 `WeighingPhotoDialog.razor` 或等效片段）：双槽位「车牌识别」「现场抓拍」，调用 `GetApprovalAttachmentsAsync`，空图占位
- [ ] 3.2 `WeighingRecord.razor`：增加操作列与「查看照片」按钮，接入共享弹层
- [ ] 3.3 `WeighingApproval.razor`：操作列增加「查看照片」（与审批/修改历史并列），接入共享弹层
- [ ] 3.4 审批弹层内图片加载逻辑与共享方法对齐（避免重复实现）

## 4. 验证

- [ ] 4.1 单元/集成：上传 API 拒绝非法 attachType；`FileService` 仅分类 Lrp/UrbanPhoto
- [ ] 4.2 联调：客户端上云后 Web 两页「查看照片」可显示 Lrp 与现场抓拍
- [ ] 4.3 联调：审批弹层内图片预览与「查看照片」弹层结果一致
