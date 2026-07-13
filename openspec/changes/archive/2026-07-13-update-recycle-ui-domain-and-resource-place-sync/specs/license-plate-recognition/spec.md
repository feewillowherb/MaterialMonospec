## ADDED Requirements

### Requirement: 无 CameraConfigs 时 LPR 双附件落盘
当 `SettingsEntity.CameraConfigs` 为空（无海康称重相机配置）时，系统 SHALL 在 LPR 识别落盘时同时创建 `AttachType.Lpr` 与 `AttachType.UnmatchedEntryPhoto` 两条 `AttachmentFile`，二者 `LocalPath` 相同；SHALL 在创建称重记录后挂接到该 `WeighingRecord`。

#### Scenario: 无相机时双附件
- **WHEN** `CameraConfigs.Count == 0`
- **AND** LPR 识别成功并落盘 `Lpr/xxx.jpg`
- **AND** 创建称重记录
- **THEN** 数据库 SHALL 存在 `AttachType.Lpr` 与 `AttachType.UnmatchedEntryPhoto` 两条记录
- **AND** 二者 `LocalPath` SHALL 相同

#### Scenario: 有 CameraConfigs 时不自动创建 UnmatchedEntryPhoto
- **WHEN** `CameraConfigs.Count > 0`
- **AND** LPR 识别成功
- **THEN** SHALL NOT 因 LPR  alone 自动创建 `UnmatchedEntryPhoto`（沿用现有 Hik 抓拍链路）

### Requirement: 非 UrbanMode 下无相机时 LPR 仍落盘
当 `CameraConfigs` 为空时，Hikvision/Vzvision LPR 服务 SHALL 允许在 `WeighingMode` 为 Standard、SolidWaste 或 Recycle 时落盘 LPR 图片，SHALL NOT 因非 `UrbanMode` 直接返回 null。

#### Scenario: Recycle 模式 LPR 落盘
- **WHEN** `WeighingMode` 为 `Recycle`
- **AND** `CameraConfigs` 为空
- **AND** LPR 回调触发
- **THEN** SHALL 写入 `Lpr/` 目录下的 jpg 文件

### Requirement: CreateWeighingRecord 调用 LPR 保存
`WeighingRecordService.CreateWeighingRecordAsync` SHALL 在存在 LPR 路径且（`WeighingMode.UrbanMode` **或** `CameraConfigs` 为空）时调用 `SaveLprAttachmentAsync`。

#### Scenario: Recycle 无相机创建记录
- **WHEN** 在 Recycle 模式创建称重记录
- **AND** `CameraConfigs` 为空
- **AND** 存在 LPR 图片路径
- **THEN** SHALL 调用 `SaveLprAttachmentAsync` 挂接 LPR 附件
