## MODIFIED Requirements

### Requirement: Urban 应用启动进入唯一主界面

MaterialClient.Urban 应用启动时 MUST 直接显示称重主界面（UrbanAttendedWeighingWindow），MUST NOT 显示登录窗口或授权窗口。启动完成后 SHALL 通过 ABP 容器初始化称重管线服务。

#### Scenario: 正常启动流程
- **WHEN** 用户启动 MaterialClient.Urban 应用
- **THEN** SHALL 通过 ABP AbpApplicationFactory 初始化应用
- **AND** SHALL 直接显示称重主界面 UrbanAttendedWeighingWindow（1280×800）
- **AND** SHALL NOT 显示登录窗口
- **AND** SHALL NOT 显示授权窗口
- **AND** SHALL 记录授权检查结果到日志（Debug 模式）
- **AND** SHALL 通过 ABP 隐式注册解析 ViewModel 和服务

#### Scenario: 启动失败处理
- **WHEN** ABP 初始化失败
- **THEN** SHALL 记录错误日志
- **AND** SHALL 调用 desktop.Shutdown() 退出应用

### Requirement: Urban 配置模式

MaterialClient.Urban MUST 使用 UrbanMode = 201 和 ProductCode = 5030，MUST NOT 支持其他 WeighingMode。配置 SHALL 通过 ISettingsService 查询。

#### Scenario: Urban 模式识别
- **WHEN** 应用通过 ISettingsService 查询当前 WeighingMode
- **THEN** SHALL 返回 UrbanMode (201)
- **AND** 通过 GetProductCodeAsync() SHALL 返回 ProductCode.Urban (5030)

#### Scenario: 标题栏显示
- **WHEN** 主界面加载完成
- **THEN** SHALL 显示"凡东城管地磅系统"标题
- **AND** SHALL 显示英文副标题

### Requirement: 主界面布局四行结构

MaterialClient.Urban 主界面 MUST 采用四行三列布局，结构与 MaterialClient AttendedWeighingWindow 保持一致。使用 MaterialClient 共享样式类替代内联样式。

#### Scenario: 主界面布局
- **WHEN** 主界面加载完成
- **THEN** SHALL 显示标题栏（Row 0, Auto height, #4169E1 背景）
- **AND** SHALL 显示重量区（Row 1, Auto height, #4A85F9 渐变背景）
- **AND** SHALL 显示三列内容区（Row 2, *）：
  - Col 0 (280px): 称重记录列表 + 筛选 + 分页
  - Col 1 (*): 主内容区
  - Col 2 (360px): 照片显示区
- **AND** SHALL 显示设备状态栏（Row 3, Auto height, #F5F5F5 背景）

#### Scenario: 窗口尺寸
- **WHEN** 主界面首次显示
- **THEN** SHALL 设置窗口大小为 1280×800
- **AND** SHALL 设置最小大小为 900×600
- **AND** SHALL 居中显示在屏幕上

### Requirement: 样式复用与隔离

MaterialClient.Urban MUST 复用 MaterialClient 主应用的共享样式类（primary-button, titlebar-close-button, titlebar-minimize-button, tab-button, card-border 等），MUST NOT 定义与 MaterialClient 重复的内联样式。

#### Scenario: 全局样式定义
- **WHEN** App.axaml 加载
- **THEN** SHALL 引用 MaterialClient 共享样式（FluentTheme, DataGrid styles）
- **AND** SHALL 使用 primary-button 样式替代自定义 search-btn
- **AND** SHALL 使用 titlebar-close-button 样式替代自定义 titlebar-close-btn
- **AND** SHALL 使用 titlebar-minimize-button 样式替代自定义 titlebar-btn
- **AND** SHALL 使用 tab-button 样式替代自定义 tab-btn

#### Scenario: 样式一致性
- **WHEN** 用户查看主界面
- **THEN** 标题栏 SHALL 使用 #4169E1 蓝色背景（与 MaterialClient 一致）
- **AND** 按钮 SHALL 使用 MaterialClient 共享样式类
- **AND** MUST NOT 使用 #0F172A 暗色主题背景

### Requirement: 无 Generic Host 交付形态

MaterialClient.Urban MUST NOT 使用 Generic Host 作为交付形态，MUST 使用 Avalonia ApplicationLifetime 配合 ABP 容器。

#### Scenario: 应用生命周期
- **WHEN** 应用启动
- **THEN** SHALL 使用 Avalonia 的 ApplicationLifetime
- **AND** SHALL 使用 ABP AbpApplicationFactory 初始化服务
- **AND** MUST NOT 注册 Generic Host
- **AND** MUST NOT 注册主 MaterialClient 的登录/Session 模块

#### Scenario: 应用退出
- **WHEN** 用户关闭应用窗口
- **THEN** SHALL 按顺序清理：ViewModel → 硬件设备 → ABP Shutdown → Serilog flush
- **AND** SHALL 在 10 秒内完成清理

### Requirement: 静态授权检查

MaterialClient.Urban MUST 在 ABP 模块的 OnApplicationInitializationAsync 中执行静态授权检查（IStaticLicenseChecker），MUST NOT 向 UI 暴露授权状态。

#### Scenario: 后台授权检查
- **WHEN** ABP 模块 OnApplicationInitializationAsync 执行
- **THEN** SHALL 调用 IStaticLicenseChecker.CheckLicenseAsync
- **AND** SHALL 读取 LicenseFilePath 配置
- **AND** SHALL 记录检查结果到日志
- **AND** MUST NOT 显示授权对话框

## ADDED Requirements

### Requirement: UrbanAttendedWeighingWindow naming

The main weighing window MUST be named `UrbanAttendedWeighingWindow` with corresponding `UrbanAttendedWeighingViewModel`, replacing the previous `WeighingSystemWindow` naming.

#### Scenario: File naming
- **WHEN** the project is built
- **THEN** the window XAML file SHALL be named `UrbanAttendedWeighingWindow.axaml`
- **AND** the code-behind SHALL be named `UrbanAttendedWeighingWindow.axaml.cs`
- **AND** the ViewModel SHALL be named `UrbanAttendedWeighingViewModel.cs`
- **AND** the class names SHALL match file names

#### Scenario: No references to old name
- **WHEN** searching the codebase for "WeighingSystem"
- **THEN** no references SHALL exist in `MaterialClient.Urban/` project files
- **AND** the AGENTS.md Urban section SHALL reference the new window name

### Requirement: Use Common entities in Urban ViewModel

The Urban ViewModel MUST use `MaterialClient.Common.Entities.WeighingRecord` directly, MUST NOT use local duplicate entity models.

#### Scenario: ViewModel imports Common entity
- **WHEN** the ViewModel references a weighing record
- **THEN** it SHALL use `MaterialClient.Common.Entities.WeighingRecord`
- **AND** MUST NOT import from `MaterialClient.Urban.Models`

#### Scenario: XAML bindings use Common entity properties
- **WHEN** the XAML binds to a weighing record
- **THEN** plate number SHALL bind to `PlateNumber` property
- **AND** weight SHALL bind to `TotalWeight` property
- **AND** time SHALL bind to `AddDate` property
- **AND** status SHALL derive from `SyncStatus` enum

## REMOVED Requirements

### Requirement: Local duplicate entity models
**Reason**: Replaced by Common entities. `Models/WeighingRecord.cs` and `Models/DeviceStatus.cs` are deleted.
**Migration**: All references to `MaterialClient.Urban.Models.WeighingRecord` must use `MaterialClient.Common.Entities.WeighingRecord`. DeviceStatus display can be handled inline in the ViewModel or as a simple record type.
