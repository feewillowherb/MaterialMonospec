## ADDED Requirements

### Requirement: LPR 落盘使用年月日目录

Hikvision / Vzvision LPR 服务保存识别图片时，MUST 使用日期目录约定：根目录 `Lpr` 下 `{yyyy}/{MM}/{dd}/`，文件名可继续使用 `{plate}_{yyyyMMdd_HHmmss_fff}.jpg`（或等价时间戳命名）。系统 MUST 通过 `AttachmentPathUtils.GetLocalStorageAbsolutePath(AttachType.Lpr, date)`（或等价调用同一套路径辅助方法）取得目录，MUST NOT 再写入无日期层级的扁平 `Lpr/` 根目录（调试目录 `LprDebug` 除外）。返回并持久化的 `LocalPath` MUST 为相对路径，例如 `Lpr/2026/07/14/浙A12345_….jpg`。

#### Scenario: 正常识别落盘带日期目录

- **WHEN** LPR 回调含有效图片字节且保存成功
- **AND** 当前本地日期为 2026-07-14
- **THEN** 文件 MUST 存在于应用程序目录下的 `Lpr/2026/07/14/`（路径分隔符以实现平台为准）
- **AND** 返回的相对路径 MUST 包含 `2026`、`07`、`14` 段

#### Scenario: 与 UrbanPhoto 共用 Lpr 根与日期结构

- **WHEN** Urban 枪机使用 `GetLocalStorageAbsolutePath(AttachType.UrbanPhoto, now)`
- **AND** LPR 使用 `GetLocalStorageAbsolutePath(AttachType.Lpr, now)`
- **THEN** 二者 MUST 使用相同的根目录名 `Lpr` 与相同的 `{yyyy}/{MM}/{dd}` 目录结构

## MODIFIED Requirements

### Requirement: 无 CameraConfigs 时 LPR 双附件落盘
当 `SettingsEntity.CameraConfigs` 为空（无海康称重相机配置）时，系统 SHALL 在 LPR 识别落盘时同时创建 `AttachType.Lpr` 与 `AttachType.UnmatchedEntryPhoto` 两条 `AttachmentFile`，二者 `LocalPath` 相同；SHALL 在创建称重记录后挂接到该 `WeighingRecord`。

#### Scenario: 无相机时双附件
- **WHEN** `CameraConfigs.Count == 0`
- **AND** LPR 识别成功并落盘至 `Lpr/{yyyy}/{MM}/{dd}/` 下的 jpg
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
- **THEN** SHALL 写入 `Lpr/{yyyy}/{MM}/{dd}/` 目录下的 jpg 文件
