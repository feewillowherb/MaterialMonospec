## ADDED Requirements

### Requirement: UrbanPhoto 附件类型保存

MaterialClient.Urban MUST 在 UrbanMode = 201 时，将海康称重抓拍图片保存为 `AttachType.UrbanPhoto` 附件，并与对应 `WeighingRecord` 建立关联。MUST NOT 在 UrbanMode 下将称重抓拍保存为 `EntryPhoto` 或 `UnmatchedEntryPhoto`。

#### Scenario: Urban 称重抓拍落库为 UrbanPhoto
- **WHEN** WeighingMode = UrbanMode (201) 且称重稳定后完成海康相机抓拍
- **THEN** SHALL 为每张成功抓拍创建 `AttachmentFile`，且 `AttachType = UrbanPhoto`
- **AND** SHALL 通过 `WeighingRecordAttachment` 关联到当前称重记录
- **AND** SHALL 在 `AttachmentFile.LocalPath` 存储相对路径

#### Scenario: Urban UI 展示 UrbanPhoto
- **WHEN** 用户选中一条 Urban 称重记录且存在 UrbanPhoto 附件
- **THEN** `UrbanAttendedWeighingViewModel` SHALL 将该附件路径绑定为相机照片（CameraPhoto）
- **AND** MUST NOT 依赖 `AttachType.EntryPhoto` 加载城管相机照片

#### Scenario: 非 Urban 模式不使用 UrbanPhoto
- **WHEN** WeighingMode != UrbanMode (201)
- **THEN** MUST NOT 创建 `AttachType.UrbanPhoto` 附件

## MODIFIED Requirements

### Requirement: Lrp 附件类型保存

MaterialClient.Urban MUST 在 UrbanMode = 201 时保存车牌识别图片为 Lrp 类型附件，MUST NOT 在其他模式保存 Lrp 附件。Lrp 图片 MUST 经过压缩处理。创建称重记录时，若当前称重周期内存在已落盘的 LRP 相对路径，MUST 将该路径写入 `AttachmentFile` 且 `AttachType = Lrp`，并关联至该 `WeighingRecord`。

#### Scenario: Urban 模式保存 Lrp 附件
- **WHEN** UrbanMode = 201 且车牌识别成功并已生成 LRP 图片文件
- **THEN** SHALL 在创建称重记录时写入 `AttachmentFile`，`AttachType = Lrp`
- **AND** SHALL 使用 `JpegCompressionUtil.TryCompressJpegBytes` 压缩图片（在 LPR 服务落盘阶段）
- **AND** SHALL 压缩质量保持车牌识别清晰度
- **AND** SHALL 通过 `WeighingRecordAttachment` 关联到当前称重记录

#### Scenario: 非Urban 模式不保存 Lrp 附件
- **WHEN** WeighingMode != UrbanMode (201)
- **THEN** MUST NOT 保存 Lrp 类型附件
- **AND** SHALL 使用现有附件类型（Photo 等）

#### Scenario: Hikvision Lrp 附件保存
- **WHEN** HikvisionLprService 执行车牌识别且 WeighingMode = UrbanMode
- **THEN** SHALL 将识别结果图片落盘并在称重记录创建时关联为 Lrp 类型
- **AND** SHALL 压缩图片以减少存储空间
- **AND** SHALL 通过 `LicensePlateRecognizedEventData.LrpImagePath` 传递相对路径供称重落库使用

#### Scenario: Vzvision Lrp 附件保存
- **WHEN** VzvisionLprService 执行车牌识别且 WeighingMode = UrbanMode
- **THEN** SHALL 将识别结果图片落盘并在称重记录创建时关联为 Lrp 类型
- **AND** SHALL 压缩图片以减少存储空间
- **AND** SHALL 通过 `LicensePlateRecognizedEventData.LrpImagePath` 传递相对路径供称重落库使用

#### Scenario: Lrp 图片压缩质量
- **WHEN** 压缩 Lrp 图片
- **THEN** SHALL 使用适当的 JPEG 质量（85-95%）
- **AND** SHALL 确保车牌号码仍然清晰可识别
- **AND** SHALL 减少文件大小至少 30%

#### Scenario: 当前周期无 LRP 图片
- **WHEN** UrbanMode = 201 但当前称重周期内无 `LrpImagePath`
- **THEN** SHALL 仍创建称重记录与 UrbanPhoto 附件（若有抓拍）
- **AND** MUST NOT 创建空的 Lrp 附件记录
