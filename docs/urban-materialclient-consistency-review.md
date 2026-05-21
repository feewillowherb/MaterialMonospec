# Urban 与 MaterialClient 一致性评审报告

> 审查日期：2026-05-21
> 审查范围：MaterialClient.Urban vs MaterialClient（主应用）
> 审查维度：UI 样式风格、代码风格

---

## 一、UI 样式风格

### 1.1 App.axaml 样式体系

| 维度 | MaterialClient | Urban | 差异 |
|------|---------------|-------|------|
| 主题框架 | `FluentTheme` + `SemiTheme` + `Ursa SemiTheme` | 仅 `FluentTheme` | **缺失** Semi/Ursa 主题 |
| 颜色资源 | 10 个命名 `SolidColorBrush`（PrimaryBlue、LightBlue 等） | 无命名颜色资源，全部硬编码 | **不一致** — 颜色硬编码，后续改动需逐处替换 |
| Converters | 12 个自定义 Converter | 0 个 | **缺失** |
| 按钮样式 | 13 种（primary、brand-primary、success、warning、danger、outline、delivery、tab、transparent 等） | 7 种（primary、secondary、tab、titlebar、popup-menu） | **缺失** brand-primary、success、warning、danger、outline、delivery、transparent、combo-trigger |
| DataGrid 选中行 | 蓝色选中行 + 左侧蓝色指示条 + 白色文字 | **缺失** 选中行样式 | **不一致** |
| ComboBox/CalendarDatePicker | 全局 focus 蓝色边框样式 | **缺失** | **不一致** |
| 全局 hover 抑制 | 有（`Button:pointerover /template/ ContentPresenter`） | 有 | 一致 |
| Ursa MessageBox 样式覆盖 | 有（修复 No 按钮 hover 色回归） | **缺失**（但 Urban 未用 Ursa，暂无影响） | N/A |

### 1.2 主窗口布局

| 维度 | MaterialClient AttendedWeighingWindow | UrbanAttendedWeighingWindow | 差异 |
|------|--------------------------------------|----------------------------|------|
| 窗口装饰 | `SystemDecorations="None"` + 自绘标题栏 | `SystemDecorations="BorderOnly"` + 自绘标题栏 | **不一致** — None vs BorderOnly |
| 窗口图标 | `Icon="/Assets/fd-ico.ico"` | **缺失** | **缺失** |
| 背景色 | `Background="White"` | `Background="#F5F5F5"` | **不一致** |
| 布局结构 | 4 行：标题栏 / 重量区 / 内容区（3 列 280+*+360） / 状态栏 | 4 行：标题栏 / 重量区 / 内容区（2 列 *+360） / 状态栏 | 一致（设计上两列 vs 三列是有意为之） |
| Logo | `<Image Source="/Assets/Indexlogo.png">` (210x32) | `<Border>` 内嵌 "凡" 字（32x32） | **不一致** — Urban 用占位符，未使用真实 Logo |
| 菜单栏 | "数据管理"（含弹窗子菜单）+ "系统设置" + "项目信息" + "数据同步" + "退出登录" | 仅 "系统设置" | 设计上有意简化 |
| 窗口按钮尺寸 | 40x40，FontSize 16/18 | 无明确尺寸/字号设置 | **不一致** — 按钮可点击区域不同 |
| 数据表头 | 使用 `DataGrid` 控件 + 全局样式（#6498FE 蓝色表头） | 手写 `Border` + `Grid` 模拟表头（#4169E1 蓝色） | **不一致** — Urban 用手写列表替代 DataGrid |
| 照片区 | 使用自定义控件（`views:PhotoGridView`） | 手写 `Border` + 占位符文字 "🚛" | **不一致** — Urban 照片功能未接入 |
| 状态栏设备 | 6 个（地磅、摄像头、USB摄像头、打印机、音响、车牌识别） | 3 个硬编码占位 | **不一致** — 设备数量和来源 |

### 1.3 XAML 代码风格

| 维度 | MaterialClient | Urban | 差异 |
|------|---------------|-------|------|
| `FontFamily` 重复 | 在多处重复声明 `'Microsoft YaHei UI', 'SimHei', ...` | **同样重复** | 两者均有此问题，建议提取为资源 |
| 内联颜色 | 使用命名资源（部分硬编码） | **全部硬编码** | **不一致** |
| 绑定模式 | `x:DataType` 编译绑定 + 丰富命令绑定 | `x:DataType` 编译绑定 + 简单属性绑定 | 风格一致 |
| `DataTemplate` | 分离为独立控件或文件 | 内联在主窗口 XAML 中 | **不一致** — Urban 内联模板使主窗口 XAML 膨胀 |

---

## 二、代码风格

### 2.1 Program.cs

| 维度 | MaterialClient | Urban | 差异 |
|------|---------------|-------|------|
| Mutex 单实例 | 有 | 有（已移植） | 一致 |
| CultureInfo 设置 | `zh-CN` | `zh-CN`（已移植） | 一致 |
| `UseReactiveUI()` | 有 | **缺失** — 仅 `.WithInterFont().LogToTrace()` | **不一致** — Urban ViewModel 继承 `ReactiveObject` 但未启用 ReactiveUI 平台集成 |
| 类声明 | `internal sealed class Program` | `class Program`（无修饰符） | **不一致** — 缺少 `internal sealed` |

### 2.2 Module 生命周期

| 维度 | MaterialClientModule | MaterialClientUrbanModule | 差异 |
|------|---------------------|--------------------------|------|
| `PreConfigureServices` | 有（加载 appsettings.secret.json + DEBUG UserSecrets） | 有（已移植，**缺失** DEBUG UserSecrets） | **不一致** |
| `ConfigureServices` | 注册 Refit API、MainWindow、Config 对象、StartupService、WebHost | 注册 WeighingStrategy、Window、ViewModel | 一致（功能差异是有意为之） |
| `services.AddHttpClient()` | 通过 Refit 隐式注册 | **缺失** | **不一致** — 这是 SoundDeviceService 激活失败的根因 |
| `ConfigureSerilog` | 日志文件名 `MaterialClient-.log` | 日志文件名 `MaterialClient.Urban-.log` | 一致 |
| `OnApplicationInitializationAsync` | DB 迁移 + BackgroundWorker + 车牌推荐缓存初始化 | DB 迁移 + 静态授权检查 | 一致（功能差异是有意为之） |
| `OnApplicationShutdownAsync` | `Log.CloseAndFlushAsync()` + `base` | 同 | 一致 |
| 命名空间大括号 | `namespace MaterialClient { ... }`（block scoped） | `namespace MaterialClient.Urban;`（file scoped） | **不一致** |

### 2.3 App.axaml.cs

| 维度 | MaterialClient | Urban | 差异 |
|------|---------------|-------|------|
| 初始化方式 | `AppBuilder.Configure<App>()` 标准模式 | 相同 | 一致 |
| ABP 生命周期 | `AbpApplicationFactory.CreateAsync` | 相同 | 一致 |
| Window 解析方式 | 在 `AttendedWeighingWindow` 构造中从 `IServiceProvider` 解析 ViewModel | 在 App 中直接从 ABP 容器解析 Window | **不一致** — DI 注入点不同 |
| ViewModel 初始化 | `Opened` 事件内 `await viewModel.InitializeOnFirstLoadAsync()` | `Opened` 事件内 `viewModel.Initialize()` + `LoadDeviceStatuses()` | **不一致** — 同步 vs 异步 |
| Exit 清理顺序 | 在 `AttendedWeighingWindow.OnClosed` 中 dispose ViewModel + `Shutdown()` | 在 App 的 `desktop.Exit` 中：ViewModel → 硬件 → ABP → Serilog | **不一致** — 清理职责位置不同 |

### 2.4 ViewModel

| 维度 | AttendedWeighingViewModel | UrbanAttendedWeighingViewModel | 差异 |
|------|--------------------------|-------------------------------|------|
| 基类 | `ViewModelBase` + `ITransientDependency` + `IDisposable` | `ReactiveObject` + `IDisposable` | **不一致** — 未使用 `ViewModelBase`，未标记 `ITransientDependency` |
| 属性方式 | `[Reactive]` Source Generator | 手写 `RaiseAndSetIfChanged` | **不一致** — Urban csproj 已引用 `ReactiveUI.SourceGenerators` 但未使用 `[Reactive]` |
| 事件订阅 | `CompositeDisposable` 管理 | `List<IDisposable>` 手动管理 | **不一致** — 未用 ReactiveUI 的 `CompositeDisposable` |
| 构造函数注入 | 10 个服务 | 4 个服务 | 功能差异是有意为之 |
| ABP 标记 | `ITransientDependency` | **无 ABP 生命周期标记** | **不一致** — 手动在 Module 中 `services.AddTransient` 注册，而非常规的 ABP 自动扫描 |
| XML 文档注释 | 全英文 `/// <summary>` | 全英文 `/// <summary>` | 一致 |
| 代码注释 | 中文 | 中文 | 一致 |

### 2.5 Code-Behind

| 维度 | AttendedWeighingWindow.axaml.cs | UrbanAttendedWeighingWindow.axaml.cs | 差异 |
|------|-------------------------------|-------------------------------------|------|
| ABP 标记 | `ITransientDependency` | **无** | **不一致** |
| Window 注册 | 通过 `ITransientDependency` 自动注册 | Module 中手动 `services.AddSingleton` | **不一致** — 单例 vs Transient |
| ViewModel 解析 | 构造函数注入 `IServiceProvider` → `GetService<AttendedWeighingViewModel>` | 构造函数直接注入 `UrbanAttendedWeighingViewModel` | **不一致** |
| Dialog/子窗口 | 丰富的子窗口管理（MaterialManagement、SupplyManagement、LedgerManagement） | **无** | 设计上有意简化 |
| 事件处理命名 | `OnMinimizeButtonClick` / `OnCloseButtonClick` | `OnMinimizeClick` / `OnCloseClick` | **不一致** — 命名约定不同（`ButtonClick` vs `Click`） |

### 2.6 csproj

| 维度 | MaterialClient.csproj | MaterialClient.Urban.csproj | 差异 |
|------|----------------------|----------------------------|------|
| Framework Ref | `<FrameworkReference Include="Microsoft.AspNetCore.App" />` | **缺失** | **不一致** — Urban 不需要 Web（设计正确） |
| Semi/Ursa 主题 | `Semi.Avalonia` + `Irihi.Avalonia.Shared` | **缺失** | 与 App.axaml 主题缺失对应 |
| User Secrets | `UserSecretsId` + DEBUG 条件引用 | **缺失** | **不一致** |
| Avalonia 绑定 | `AvaloniaUseCompiledBindingsByDefault = true` | `false` | **不一致** |
| 发布配置 | 无 `PublishSingleFile` 等 | `PublishReadyToRun` + `PublishSingleFile` + `SelfContained` | 功能差异合理 |

---

## 三、关键问题汇总（按严重程度排序）

### P0 — 运行时阻断

1. **`Program.cs` 缺少 `.UseReactiveUI()`** — ViewModel 继承 `ReactiveObject` 但未启用平台集成，`RxApp.MainThreadScheduler` 等可能行为异常
2. **Module 缺少 `services.AddHttpClient()`** — 这是 SoundDeviceService 无法解析 `IHttpClientFactory` 的根因

### P1 — 代码风格不一致

3. ViewModel 未使用 `[Reactive]` Source Generator（已引入包但未使用）
4. ViewModel/Window 未标记 `ITransientDependency`（ABP 自动扫描 vs 手动注册）
5. Window 注册生命周期不一致（`Singleton` vs MaterialClient 的 `Transient` + `ITransientDependency`）
6. 命名空间风格不一致（block scoped vs file scoped）
7. Program 类缺少 `internal sealed` 修饰符
8. 事件处理方法命名约定不一致（`OnXxxClick` vs `OnXxxButtonClick`）

### P2 — UI 样式缺失

9. App.axaml 缺少命名颜色资源（全部硬编码色值）
10. 缺少 SemiTheme / Ursa 主题
11. 缺少 DataGrid 选中行样式
12. 窗口 `SystemDecorations` 不一致（`None` vs `BorderOnly`）
13. 缺少 ComboBox / CalendarDatePicker focus 样式
14. 缺少窗口 Icon
15. PreConfigureServices 缺少 `#if DEBUG` UserSecrets 支持

### P3 — 改进建议

16. 内联 DataTemplate 应提取为独立控件（减少主窗口 XAML 复杂度）
17. FontFamily 字符串应提取为共享资源
18. 手写表头应改用 DataGrid（已有全局 DataGrid 样式定义）
