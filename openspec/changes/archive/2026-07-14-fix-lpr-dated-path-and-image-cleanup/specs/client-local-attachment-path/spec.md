## ADDED Requirements

### Requirement: UrbanPhoto 本地根目录与 Lpr 相同

`AttachmentPathUtils.GetBasePath(AttachType.UrbanPhoto)` MUST 返回 `"Lpr"`，与 `GetBasePath(AttachType.Lpr)` 相同。因此 `GetLocalStoragePath` / `GetLocalStorageAbsolutePath` / `GetStoragePath` / `GetOssObjectKey` 在 `AttachType.UrbanPhoto` 下 MUST 使用根 `Lpr` 与日期段 `{yyyy}/{MM}/{dd}`。`AttachType.UrbanPhoto` 的枚举值与业务挂接语义 MUST NOT 因此改变。

#### Scenario: Urban 枪机落盘在 Lpr 日期目录

- **WHEN** UrbanMode 下枪机抓拍调用 `GetLocalStorageAbsolutePath(AttachType.UrbanPhoto, 2026-07-14)`
- **THEN** 返回路径 MUST 落在应用程序目录下的 `Lpr/2026/07/14/`（分隔符以实现平台为准）
- **AND** MUST NOT 使用 `PhotoUrban` 作为新写入根目录

#### Scenario: GetBasePath 对齐

- **WHEN** 分别调用 `GetBasePath(AttachType.UrbanPhoto)` 与 `GetBasePath(AttachType.Lpr)`
- **THEN** 二者 MUST 均返回 `"Lpr"`

### Requirement: EntryPhoto 仍使用 PhotoJianKong

非 Urban 枪机路径 MUST 保持不变：`GetBasePath` 对默认 / EntryPhoto 相关类型仍返回 `"PhotoJianKong"`（既有行为）。

#### Scenario: 非 Urban 抓拍根不变

- **WHEN** 调用 `GetLocalStorageAbsolutePath(AttachType.EntryPhoto, date)`
- **THEN** 路径 MUST 以 `PhotoJianKong/{yyyy}/{MM}/{dd}/` 为前缀
