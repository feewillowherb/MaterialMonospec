# MaterialClient Urban Desktop Specification

## Purpose

定义 MaterialClient Urban 桌面应用的功能需求，包括单窗口称重主界面、静态授权检查、以及与 MaterialClient 主应用的架构差异。

## Requirements

### Requirement: Urban 应用启动进入唯一主界面

MaterialClient.Urban 应用启动时 MUST 直接显示称重主界面（UrbanAttendedWeighingWindow），MUST NOT 显示登录窗口或授权窗口。启动完成后 SHALL 通过 ABP 容器初始化称重管线服务。

#### Scenario: 正常启动流程
- **WHEN** 用户启动 MaterialClient.Urban 应用
- **THEN** SHALL 通过 ABP AbpApplicationFactory 初始化应用
- **AND** SHALL 在 Program.cs 中配置 `.UseReactiveUI()` 平台集成
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

### Requirement: 顶栏菜单精简

MaterialClient.Urban 顶栏菜单 MUST 仅包含"系统设置"入口，MUST NOT 包含"退出登录"等与登录相关的菜单项。"系统设置"按钮 MUST 打开 MaterialClient.UI 提供的共享 `SettingsWindow`（与 MaterialClient 主程序相同的完整设置界面）。

#### Scenario: 顶栏菜单显示
- **WHEN** 用户查看顶栏菜单
- **THEN** SHALL 显示"系统设置"按钮（启用）
- **AND** SHALL NOT 显示"退出登录"按钮
- **AND** SHALL NOT 显示"数据同步"按钮（首期）
- **AND** SHALL NOT 显示"项目信息"按钮（首期）

#### Scenario: 系统设置入口
- **WHEN** 用户点击"系统设置"按钮
- **THEN** SHALL 打开 MaterialClient.UI 的 `SettingsWindow` 窗口
- **AND** `SettingsWindow` SHALL 显示与 main 分支一致的七个设置分区（地磅、称重、摄像头、车牌识别、系统、音响、打印机）
- **AND** SHALL 允许修改系统配置并保存到本地设置存储
- **AND** MUST NOT 打开 `SettingsDialog` 或依赖 `ISettingsSection` 自动发现

### Requirement: 静态授权检查

MaterialClient.Urban MUST 在 ABP 模块的 OnApplicationInitializationAsync 中执行静态授权检查（IStaticLicenseChecker），MUST NOT 向 UI 暴露授权状态。

#### Scenario: 后台授权检查
- **WHEN** ABP 模块 OnApplicationInitializationAsync 执行
- **THEN** SHALL 调用 IStaticLicenseChecker.CheckLicenseAsync
- **AND** SHALL 读取 LicenseFilePath 配置
- **AND** SHALL 记录检查结果到日志
- **AND** MUST NOT 显示授权对话框

#### Scenario: Debug 模式状态显示
- **WHEN** 应用在 Debug 模式下运行
- **THEN** SHALL 在设备状态栏显示授权状态文本
- **AND** SHALL 使用绿色（成功）或红色（失败）指示器

### Requirement: 主界面布局四行结构

MaterialClient.Urban 主界面 MUST 采用四行三列布局。设备状态栏（Row 3）MUST 使用 MaterialClient.UI 的 DeviceStatusBar 共享控件替代内联实现。使用 MaterialClient 共享样式类替代内联样式。

#### Scenario: 主界面布局
- **WHEN** 主界面加载完成
- **THEN** SHALL 显示标题栏（Row 0, Auto height, #4169E1 背景）
- **AND** SHALL 显示重量区（Row 1, Auto height, #4A85F9 渐变背景）
- **AND** SHALL 显示三列内容区（Row 2, *）：
  - Col 0 (280px): 称重记录列表 + 筛选 + 分页
  - Col 1 (*): 主内容区
  - Col 2 (360px): 照片显示区
- **AND** SHALL 显示 MaterialClient.UI DeviceStatusBar 控件（Row 3, Auto height）

#### Scenario: 重量区显示真实称重数据
- **WHEN** 称重管线正在运行
- **THEN** 重量区 SHALL 显示 CurrentWeight（由 ViewModel 绑定驱动）
- **AND** SHALL 显示 WeightStatus 文案和对应颜色
- **AND** SHALL NOT 显示 mock 数据

#### Scenario: 窗口配置
- **WHEN** 主界面首次显示
- **THEN** SHALL 设置窗口大小为 1280×800
- **AND** SHALL 设置最小大小为 900×600
- **AND** SHALL 居中显示在屏幕上
- **AND** SHALL 使用 `SystemDecorations="None"`（与 MaterialClient 一致）
- **AND** SHALL 设置窗口 Icon（`/Assets/fd-ico.ico`）

### Requirement: 照片显示区域

MaterialClient.Urban 右侧照片区 MUST 显示两张照片：车牌识别抓拍和摄像头抓拍，MUST 支持从本地缓存或服务器加载。照片 MUST 通过 Avalonia `Image` 控件绑定，并使用 MaterialClient.UI 提供的 `CarNullOrEmptyImageConverter` 处理空路径与加载失败。

#### Scenario: 照片区域布局
- **WHEN** 用户查看称重记录详情
- **THEN** SHALL 显示"车牌识别抓拍"照片区域（高度 120px）
- **AND** SHALL 显示"摄像头抓拍"照片区域（高度 120px）
- **AND** SHALL 显示照片拍摄时间
- **AND** 每个照片区域 SHALL 使用 `Image` 控件（非 emoji `TextBlock` 占位）

#### Scenario: 照片加载逻辑
- **WHEN** 用户选择一条称重记录
- **THEN** SHALL 优先从本地缓存加载照片
- **AND** 如果本地缓存不存在，SHALL 从服务器加载照片
- **AND** SHALL 将下载的照片保存到本地缓存
- **AND** ViewModel SHALL 向 UI 暴露可绑定的照片路径字符串属性（车牌识别、摄像头各一）

#### Scenario: 照片 XAML 绑定
- **WHEN** UrbanAttendedWeighingWindow 显示照片区域
- **THEN** 车牌识别 `Image.Source` SHALL 绑定到 ViewModel 车牌照片路径
- **AND** SHALL 使用 `Converter={StaticResource CarNullOrEmptyImageConverter}`
- **AND** 摄像头 `Image.Source` SHALL 绑定到 ViewModel 摄像头照片路径
- **AND** SHALL 使用同一 `CarNullOrEmptyImageConverter` 静态资源

#### Scenario: 照片加载失败
- **WHEN** 照片路径为空、无效或文件不存在
- **THEN** `CarNullOrEmptyImageConverter` SHALL 显示默认车辆图片（`Car_Default.png`）
- **AND** SHALL NOT 使用 emoji（🚛）作为占位
- **AND** 照片容器 MAY 保留灰色边框背景样式

### Requirement: 设备状态栏实时更新

MaterialClient.Urban 设备状态栏 MUST 使用 MaterialClient.UI 的 DeviceStatusBar 共享控件实时显示设备在线状态，MUST NOT 使用内联状态栏实现。设备集合 MUST 与主应用完全一致。

#### Scenario: 设备状态显示
- **WHEN** 主界面加载完成
- **THEN** SHALL 使用 `<ui:DeviceStatusBar>` 控件显示设备状态
- **AND** SHALL 绑定到共享 DeviceStatusBarViewModel
- **AND** SHALL 显示地磅设备状态（● 在线/离线）
- **AND** SHALL 显示所有摄像头状态（● 在线/离线）
- **AND** SHALL 显示 USB 摄像头状态（● 在线/离线）
- **AND** SHALL 显示打印机状态（● 在线/离线）
- **AND** SHALL 显示音频设备状态（● 在线/离线）
- **AND** SHALL 显示车牌识别设备状态（● 在线/离线）

#### Scenario: 设备状态更新
- **WHEN** 设备状态发生变化
- **THEN** SHALL 通过 ILocalEventBus 事件驱动更新
- **AND** SHALL 在 1 秒内更新状态栏显示
- **AND** 在线设备 SHALL 显示绿色指示器
- **AND** 离线设备 SHALL 显示红色指示器

### Requirement: 无 Generic Host 交付形态

MaterialClient.Urban MUST NOT 使用 Generic Host 作为交付形态，MUST 使用 Avalonia ApplicationLifetime 配合 ABP 容器。

#### Scenario: 应用生命周期
- **WHEN** 应用启动
- **THEN** SHALL 使用 Avalonia 的 ApplicationLifetime
- **AND** SHALL 使用 ABP AbpApplicationFactory 初始化服务
- **AND** SHALL 在 Module 中注册 `services.AddHttpClient()` 以支持 IHttpClientFactory 依赖
- **AND** MUST NOT 注册 Generic Host
- **AND** MUST NOT 注册主 MaterialClient 的登录/Session 模块

#### Scenario: 应用退出
- **WHEN** 用户关闭应用窗口
- **THEN** SHALL 按顺序清理：ViewModel -> 硬件设备 -> ABP Shutdown -> Serilog flush
- **AND** SHALL 在 10 秒内完成清理

### Requirement: 样式复用与隔离

MaterialClient.Urban MUST 通过导入 MaterialClient.UI 的 SharedTheme.axaml 获取共享样式类和颜色资源，MUST NOT 定义与 SharedTheme 重复的样式。

#### Scenario: 全局样式定义
- **WHEN** App.axaml 加载
- **THEN** SHALL 导入 MaterialClient.UI 的 SharedTheme.axaml 作为合并资源字典
- **AND** SHALL 使用 SharedTheme 中的 primary-button、titlebar-close-button 等样式类
- **AND** SHALL 使用 SharedTheme 中的命名颜色画刷
- **AND** MUST NOT 重复定义 SharedTheme 中已有的颜色资源

#### Scenario: 样式一致性
- **WHEN** 用户查看主界面
- **THEN** 标题栏 SHALL 使用 SharedTheme 命名颜色资源
- **AND** 按钮 SHALL 使用 SharedTheme 共享样式类
- **AND** MUST NOT 使用硬编码色值

#### Scenario: DataGrid 选中行样式
- **WHEN** DataGrid 控件显示记录列表
- **THEN** 选中行 SHALL 显示蓝色背景 + 左侧蓝色指示条
- **AND** 选中行文字 SHALL 为白色

#### Scenario: ComboBox 和 CalendarDatePicker focus 样式
- **WHEN** ComboBox 或 CalendarDatePicker 获得焦点
- **THEN** SHALL 显示蓝色边框样式
- **AND** 样式 SHALL 与 MaterialClient 一致

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

The Urban ViewModel MUST use `MaterialClient.Common.Entities.WeighingRecord` directly, MUST NOT use local duplicate entity models. The ViewModel MUST NOT directly inject `IRepository<WeighingRecord, long>` or any other Repository — all data access SHALL go through `IWeighingRecordService`.

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

#### Scenario: ViewModel uses Service for data access
- **WHEN** the ViewModel needs to query weighing records
- **THEN** it SHALL use `IWeighingRecordService.GetPagedUrbanWeighingRecordsAsync`
- **AND** MUST NOT inject `IRepository<WeighingRecord, long>` or any Repository
- **AND** MUST NOT import `Volo.Abp.Domain.Repositories`
- **AND** MUST NOT import `Microsoft.EntityFrameworkCore`

### Requirement: Lrp 附件类型保存

MaterialClient.Urban MUST 在 UrbanMode = 201 时保存车牌识别图片为 Lrp 类型附件，MUST NOT 在其他模式保存 Lrp 附件。Lrp 图片 MUST 经过压缩处理。

#### Scenario: Urban 模式保存 Lrp 附件
- **WHEN** UrbanMode = 201 且车牌识别成功
- **THEN** SHALL 保存车牌识别图片为 Lrp 类型附件
- **AND** SHALL 使用 `JpegCompressionUtil.TryCompressJpegBytes` 压缩图片
- **AND** SHALL 压缩质量保持车牌识别清晰度
- **AND** SHALL 在 Attachment 表中记录 AttachType = Lrp

#### Scenario: 非Urban 模式不保存 Lrp 附件
- **WHEN** WeighingMode != UrbanMode (201)
- **THEN** MUST NOT 保存 Lrp 类型附件
- **AND** SHALL 使用现有附件类型（Photo 等）

#### Scenario: Hikvision Lrp 附件保存
- **WHEN** HikvisionLprService 执行车牌识别且 WeighingMode = UrbanMode
- **THEN** SHALL 保存识别结果图片为 Lrp 类型
- **AND** SHALL 压缩图片以减少存储空间
- **AND** SHALL 记录附件元数据（识别时间、车牌号、设备信息）

#### Scenario: Vzvision Lrp 附件保存
- **WHEN** VzvisionLprService 执行车牌识别且 WeighingMode = UrbanMode
- **THEN** SHALL 保存识别结果图片为 Lrp 类型
- **AND** SHALL 压缩图片以减少存储空间
- **AND** SHALL 记录附件元数据（识别时间、车牌号、设备信息）

#### Scenario: Lrp 图片压缩质量
- **WHEN** 压缩 Lrp 图片
- **THEN** SHALL 使用适当的 JPEG 质量（85-95%）
- **AND** SHALL 确保车牌号码仍然清晰可识别
- **AND** SHALL 减少文件大小至少 30%

### Requirement: ReactiveUI 平台集成

MaterialClient.Urban MUST 在 Avalonia 应用构建中启用 ReactiveUI 平台集成，确保 `RxApp.MainThreadScheduler` 正确调度到 UI 线程。

#### Scenario: UseReactiveUI 配置
- **WHEN** `Program.BuildAvaloniaApp()` 被调用
- **THEN** SHALL 在构建链中包含 `.UseReactiveUI()`
- **AND** SHALL 确保 ReactiveUI 的 `MainThreadScheduler` 正确调度到 Avalonia UI 线程

### Requirement: ABP ITransientDependency 注册约定

MaterialClient.Urban 的 ViewModel 和 Window MUST 使用 ABP 的 `ITransientDependency` 接口标记进行自动注册，MUST NOT 在 Module 中手动调用 `services.AddTransient` 或 `services.AddSingleton`。

#### Scenario: ViewModel 自动注册
- **WHEN** ABP 模块扫描程序集
- **THEN** `UrbanAttendedWeighingViewModel` SHALL 通过 `ITransientDependency` 标记被自动注册
- **AND** 注册生命周期 SHALL 为 Transient

#### Scenario: Window 自动注册
- **WHEN** ABP 模块扫描程序集
- **THEN** `UrbanAttendedWeighingWindow` SHALL 通过 `ITransientDependency` 标记被自动注册
- **AND** 注册生命周期 SHALL 为 Transient（与 MaterialClient 的 AttendedWeighingWindow 一致）

#### Scenario: Module 不含手动注册
- **WHEN** 查看 `MaterialClientUrbanModule.ConfigureServices`
- **THEN** MUST NOT 包含 `services.AddTransient<UrbanAttendedWeighingViewModel>()`
- **AND** MUST NOT 包含 `services.AddSingleton<UrbanAttendedWeighingWindow>()`

### Requirement: ViewModel ReactiveUI Source Generator 属性

MaterialClient.Urban ViewModel MUST 使用 `[Reactive]` Source Generator 注解替代手写 `RaiseAndSetIfChanged` 属性。MUST 使用 `CompositeDisposable` 管理事件订阅。

#### Scenario: Reactive 属性声明
- **WHEN** ViewModel 声明响应式属性
- **THEN** SHALL 使用 `[Reactive]` 注解
- **AND** MUST NOT 使用手写 `RaiseAndSetIfChanged` 模式

#### Scenario: 订阅管理
- **WHEN** ViewModel 管理多个事件订阅
- **THEN** SHALL 使用 `CompositeDisposable`（ReactiveUI 标准）
- **AND** MUST NOT 使用 `List<IDisposable>` 手动管理

### Requirement: Urban 代码风格与 MaterialClient 一致

MaterialClient.Urban 的代码风格 MUST 与 MaterialClient 主应用保持一致。

#### Scenario: Program 类声明
- **WHEN** 定义 Program 类
- **THEN** SHALL 使用 `internal sealed class Program` 修饰符

#### Scenario: 命名空间风格
- **WHEN** 定义命名空间
- **THEN** SHALL 使用 block-scoped 命名空间（`namespace X { }`）
- **AND** MUST NOT 使用 file-scoped 命名空间（`namespace X;`）

#### Scenario: 事件处理方法命名
- **WHEN** 在 code-behind 中定义按钮点击事件处理方法
- **THEN** SHALL 使用 `OnXxxButtonClick` 命名格式
- **AND** MUST NOT 使用 `OnXxxClick` 命名格式

### Requirement: HttpClient 注册支持

MaterialClientUrbanModule MUST 注册 `IHttpClientFactory` 以支持依赖 HttpClient 的服务（如 SoundDeviceService）。

#### Scenario: AddHttpClient 注册
- **WHEN** `MaterialClientUrbanModule.ConfigureServices` 被调用
- **THEN** SHALL 调用 `services.AddHttpClient()`
- **AND** SHALL 确保所有依赖 `IHttpClientFactory` 的服务能正确解析

### Requirement: 编译绑定默认启用

MaterialClient.Urban 项目 MUST 启用 Avalonia 编译绑定默认设置，与 MaterialClient 一致。

#### Scenario: CompiledBindingsByDefault 配置
- **WHEN** 项目构建
- **THEN** `MaterialClient.Urban.csproj` 中 `AvaloniaUseCompiledBindingsByDefault` SHALL 为 `true`
- **AND** 所有 XAML 绑定 SHALL 通过编译时检查

### Requirement: PreConfigureServices DEBUG UserSecrets 支持

MaterialClientUrbanModule 的 `PreConfigureServices` MUST 在 DEBUG 模式下支持 UserSecrets，与 MaterialClientModule 一致。

#### Scenario: DEBUG 模式 UserSecrets
- **WHEN** 在 DEBUG 配置下运行应用
- **THEN** Module SHALL 加载 UserSecrets 配置源
- **AND** SHALL 使用与 MaterialClientModule 相同的 UserSecretsId 模式
