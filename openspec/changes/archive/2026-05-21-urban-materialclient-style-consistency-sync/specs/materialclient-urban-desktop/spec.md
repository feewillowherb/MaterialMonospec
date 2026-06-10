## MODIFIED Requirements

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

MaterialClient.Urban MUST 复用 MaterialClient 主应用的共享样式类（primary-button, titlebar-close-button, titlebar-minimize-button, tab-button, card-border 等），MUST NOT 定义与 MaterialClient 重复的内联样式。MUST 使用命名颜色画刷替代硬编码色值。

#### Scenario: 全局样式定义
- **WHEN** App.axaml 加载
- **THEN** SHALL 引用 MaterialClient 共享样式（FluentTheme, DataGrid styles）
- **AND** SHALL 定义命名颜色画刷（PrimaryBlue #4169E1、LightBlue #4A85F9、BackgroundGray #F5F5F5 等）
- **AND** SHALL 使用 primary-button 样式替代自定义 search-btn
- **AND** SHALL 使用 titlebar-close-button 样式替代自定义 titlebar-close-btn
- **AND** SHALL 使用 titlebar-minimize-button 样式替代自定义 titlebar-btn
- **AND** SHALL 使用 tab-button 样式替代自定义 tab-btn

#### Scenario: 样式一致性
- **WHEN** 用户查看主界面
- **THEN** 标题栏 SHALL 使用命名颜色资源（与 MaterialClient 一致）
- **AND** 按钮 SHALL 使用 MaterialClient 共享样式类
- **AND** MUST NOT 使用硬编码色值
- **AND** MUST NOT 使用 #0F172A 暗色主题背景

#### Scenario: DataGrid 选中行样式
- **WHEN** DataGrid 控件显示记录列表
- **THEN** 选中行 SHALL 显示蓝色背景 + 左侧蓝色指示条
- **AND** 选中行文字 SHALL 为白色

#### Scenario: ComboBox 和 CalendarDatePicker focus 样式
- **WHEN** ComboBox 或 CalendarDatePicker 获得焦点
- **THEN** SHALL 显示蓝色边框样式
- **AND** 样式 SHALL 与 MaterialClient 一致

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

#### Scenario: 窗口配置
- **WHEN** 主界面首次显示
- **THEN** SHALL 设置窗口大小为 1280×800
- **AND** SHALL 设置最小大小为 900×600
- **AND** SHALL 居中显示在屏幕上
- **AND** SHALL 使用 `SystemDecorations="None"`（与 MaterialClient 一致）
- **AND** SHALL 设置窗口 Icon（`/Assets/fd-ico.ico`）

## ADDED Requirements

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
