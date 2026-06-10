## MODIFIED Requirements

### Requirement: 设置与注册表同步

系统应保持数据库设置与 Windows 注册表状态一致，在检测到不一致时自动修复。

#### 场景：保存设置时同步
- **当** 通过 `SettingsService.SaveSettingsAsync()` 保存设置
- **则** 系统应：
  - 先将设置写入数据库
  - 若 `EnableAutoStart = true`，调用 `WindowsAutoStartService.EnableAutoStartAsync()`
  - 若 `EnableAutoStart = false`，调用 `WindowsAutoStartService.DisableAutoStartAsync()`
  - 确保保存后数据库与注册表状态一致

#### 场景：启动时修复不一致
- **当** 应用程序启动
- **且** 数据库中的 `EnableAutoStart` 与注册表状态不一致
- **则** 系统应：
  - 通过对比数据库设置与注册表状态检测不一致
  - 将数据库设置应用到注册表（修复不一致）
  - 记录修复操作以便排查
  - 正常继续启动（不同步失败时不阻塞启动）

#### 场景：启动时状态一致
- **当** 应用程序启动
- **且** 数据库中的 `EnableAutoStart` 与注册表状态一致
- **则** 系统应：
  - 记录状态一致
  - 不修改注册表继续启动

> **Note**: This requirement is unchanged from the base spec. Included for completeness — no behavioral modification needed.

## ADDED Requirements

### Requirement: ProductCode query interface

`ISettingsService` SHALL provide a method to query the current `ProductCode` derived from the stored `WeighingMode`.

#### Scenario: Get ProductCode from settings
- **WHEN** `GetProductCodeAsync()` is called
- **THEN** the system SHALL read the current `WeighingMode` from settings
- **AND** SHALL return `ProductCode.Standard` for `WeighingMode.Standard`
- **AND** SHALL return `ProductCode.SolidWaste` for `WeighingMode.SolidWaste`
- **AND** SHALL return `ProductCode.Urban` for `WeighingMode.UrbanMode`

#### Scenario: Default ProductCode when no settings exist
- **WHEN** `GetProductCodeAsync()` is called and no settings record exists
- **THEN** the system SHALL create default settings
- **AND** SHALL return `ProductCode.Standard`

### Requirement: SaveDefaultWeighingModeAsync supports UrbanMode

`ISettingsService.SaveDefaultWeighingModeAsync` SHALL correctly map `ProductCode.Urban` to `WeighingMode.UrbanMode`.

#### Scenario: Save Urban ProductCode
- **WHEN** `SaveDefaultWeighingModeAsync(ProductCode.Urban)` is called
- **THEN** the system SHALL set `DefaultWeighingMode = WeighingMode.UrbanMode`
- **AND** SHALL persist the settings

#### Scenario: Save Standard ProductCode
- **WHEN** `SaveDefaultWeighingModeAsync(ProductCode.Standard)` is called
- **THEN** the system SHALL set `DefaultWeighingMode = WeighingMode.Standard`

#### Scenario: Save SolidWaste ProductCode
- **WHEN** `SaveDefaultWeighingModeAsync(ProductCode.SolidWaste)` is called
- **THEN** the system SHALL set `DefaultWeighingMode = WeighingMode.SolidWaste`

## REMOVED Requirements

### Requirement: IUrbanWeighingService interface
**Reason**: Merged into ISettingsService. The two static properties (WeighingMode.UrbanMode, ProductCode.Urban) are now derivable from ISettingsService.GetWeighingModeAsync() and ISettingsService.GetProductCodeAsync().
**Migration**: Replace all IUrbanWeighingService usages with ISettingsService. Urban ViewModel shall inject ISettingsService and call GetProductCodeAsync() / GetWeighingModeAsync().
