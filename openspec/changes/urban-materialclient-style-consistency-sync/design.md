# Design: Urban MaterialClient Style Consistency Sync

## Overview

基于 `docs/urban-materialclient-consistency-review.md` 的一致性评审结果，修复 Urban 与 MaterialClient 主应用之间的运行时问题、代码风格差异和 UI 样式缺失。本变更不引入新功能，仅对齐两个应用之间的架构模式和样式规范。

## Design Decisions

### DD-1: P0 修复策略 — UseReactiveUI + AddHttpClient

**问题**：
- `Program.cs` 缺少 `.UseReactiveUI()`，导致 `RxApp.MainThreadScheduler` 无法正确调度到 UI 线程
- `MaterialClientUrbanModule.ConfigureServices` 缺少 `services.AddHttpClient()`，导致 `SoundDeviceService` 无法解析 `IHttpClientFactory`

**方案**：
- 在 `Program.cs` 的 `BuildAvaloniaApp()` 链中 `.WithInterFont().LogToTrace()` 后添加 `.UseReactiveUI()`
- 在 Module 的 `ConfigureServices` 中添加 `services.AddHttpClient()`
- 这是最小化修改，不改变现有 ViewModel 的行为，仅修复平台集成缺失

**不选方案**：
- 不重构 ViewModel 的 ReactiveUI 使用方式（这属于 P1 范畴，在后续任务中处理）

### DD-2: ABP 注册模式对齐

**问题**：Urban 的 ViewModel 和 Window 手动在 Module 中通过 `services.AddTransient`/`services.AddSingleton` 注册，而 MaterialClient 使用 `ITransientDependency` 标记实现 ABP 自动扫描。

**方案**：
- ViewModel 和 Window 添加 `ITransientDependency` 接口标记
- 移除 Module 中的手动 `services.AddTransient<UrbanAttendedWeighingViewModel>()` 和 `services.AddSingleton<UrbanAttendedWeighingWindow>()`
- Window 注册从 Singleton 改为 Transient（与 MaterialClient 的 `AttendedWeighingWindow` 一致）

**理由**：ABP 的约定优于配置模式减少样板代码，并确保所有模块遵循相同的注册模式。

### DD-3: ViewModel 属性风格统一

**问题**：Urban ViewModel 使用手写 `RaiseAndSetIfChanged` 属性，而 MaterialClient 使用 `[Reactive]` Source Generator。Urban 的 csproj 已经引用了 `ReactiveUI.SourceGenerators` 包但未使用。

**方案**：
- 将所有手写响应式属性替换为 `[Reactive]` 注解
- 将 `List<IDisposable>` 替换为 `CompositeDisposable`（ReactiveUI 的标准做法）

**迁移规则**：
```csharp
// Before
private string _statusText = string.Empty;
public string StatusText
{
    get => _statusText;
    set => this.RaiseAndSetIfChanged(ref _statusText, value);
}

// After
[Reactive]
public string StatusText { get; set; } = string.Empty;
```

### DD-4: 代码风格对齐

| 项目 | 当前 Urban | 目标（对齐 MaterialClient） |
|------|-----------|---------------------------|
| `Program` 修饰符 | `class Program` | `internal sealed class Program` |
| 命名空间 | file-scoped (`namespace X;`) | block-scoped (`namespace X { }`) |
| 事件处理方法 | `OnXxxClick` | `OnXxxButtonClick` |

### DD-5: App.axaml 样式资源补充

**问题**：Urban App.axaml 缺少命名颜色画刷，全部使用硬编码色值（如 `#4169E1`、`#4A85F9`、`#F5F5F5`）。

**方案**：
- 从 MaterialClient 的 `App.axaml` 复制核心命名颜色画刷：
  - `PrimaryBlue` (#4169E1)
  - `LightBlue` (#4A85F9)
  - `BackgroundGray` (#F5F5F5)
- 添加 DataGrid 选中行样式（蓝色选中行 + 左侧蓝色指示条 + 白色文字）
- 添加 ComboBox / CalendarDatePicker focus 蓝色边框样式
- 替换主窗口 XAML 中的硬编码色值为命名资源引用

**不添加**：
- SemiTheme / Ursa 主题 — Urban 当前不使用 Ursa 控件，引入 SemiTheme 会增加包体积且无实际收益。如后续需要 Ursa 控件再引入。
- `FrameworkReference Microsoft.AspNetCore.App` — Urban 不需要 Web 功能

### DD-6: 窗口配置对齐

| 配置项 | 当前 Urban | 目标 |
|--------|-----------|------|
| `SystemDecorations` | `BorderOnly` | `None`（与 MaterialClient 一致） |
| `Icon` | 缺失 | `/Assets/fd-ico.ico`（使用 MaterialClient 同一图标） |
| `CompiledBindingsByDefault` | `false` | `true`（启用编译绑定检查） |

### DD-7: 不在本变更范围内的项目

以下项目记录为已知差异，但不在本次修复范围内（属于 P3 改进建议或设计上有意简化）：

- 窗口背景色差异（`White` vs `#F5F5F5`）— 设计上有意为之
- 两列 vs 三列布局 — 设计上有意为之
- Logo 占位符 — 需要设计团队提供 Logo 资源
- 内联 DataTemplate 提取 — 代码重构，非一致性修复
- FontFamily 字符串提取为共享资源 — 两个应用均有此问题，应作为独立变更处理
- 手写表头改用 DataGrid — 功能性变更，非一致性修复
- 照片功能未接入 — 功能性缺失，非一致性修复
- 菜单栏简化 — 设计上有意为之

## Affected Files

| 文件路径 | 变更类型 |
|-----------|---------|
| `MaterialClient.Urban/Program.cs` | 修改 |
| `MaterialClient.Urban/MaterialClientUrbanModule.cs` | 修改 |
| `MaterialClient.Urban/ViewModels/UrbanAttendedWeighingViewModel.cs` | 修改 |
| `MaterialClient.Urban/Views/UrbanAttendedWeighingWindow.axaml.cs` | 修改 |
| `MaterialClient.Urban/Views/UrbanAttendedWeighingWindow.axaml` | 修改 |
| `MaterialClient.Urban/App.axaml` | 修改 |
| `MaterialClient.Urban/App.axaml.cs` | 修改 |
| `MaterialClient.Urban/MaterialClient.Urban.csproj` | 修改 |
